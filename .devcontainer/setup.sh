#!/bin/bash
set -e

REPO="/workspaces/se-web"
SITE="/standardebooks.org"
WEB="$SITE/web"
PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

# ==============================================================================
echo "==> Setting up directory structure..."
# ==============================================================================
sudo mkdir -p "$SITE"
sudo ln -sfn "$REPO" "$WEB"
sudo chown -R codespace: "$SITE"
sudo mkdir -p /var/log/local
sudo chown -R codespace: /var/log/local

# ==============================================================================
echo "==> Installing Composer dependencies..."
# ==============================================================================
cd "$WEB"
composer install --no-interaction

# ==============================================================================
echo "==> Setting up Python/SE toolset..."
# ==============================================================================
python3 -m venv "$WEB/.venv"
source "$WEB/.venv/bin/activate"
pip3 install --quiet standardebooks
deactivate

# ==============================================================================
echo "==> Creating self-signed SSL cert..."
# ==============================================================================
mkdir -p "$WEB/config/ssl"
openssl req -x509 -nodes -days 99999 -newkey rsa:4096 \
    -subj "/CN=standardebooks.test" \
    -keyout "$WEB/config/ssl/standardebooks.test.key" \
    -sha256 \
    -out "$WEB/config/ssl/standardebooks.test.crt" 2>/dev/null

# ==============================================================================
echo "==> Enabling Apache modules..."
# ==============================================================================
sudo a2enmod headers expires ssl rewrite proxy proxy_fcgi xsendfile

# ==============================================================================
echo "==> Configuring Apache..."
# ==============================================================================

## Mike C.: Copying instead of linking because we need to modify the file with sed below.
## Link and enable the repo's Apache config for standardebooks.test
#sudo ln -sf "$WEB/config/apache/standardebooks.test.conf" \
#    /etc/apache2/sites-available/standardebooks.test.conf
sudo cp "$WEB/config/apache/standardebooks.test.conf" \
	    /etc/apache2/sites-available/standardebooks.test.conf

sudo a2ensite standardebooks.test
sudo a2dissite 000-default || true

# The repo's Apache config blocks all requests that have X-Forwarded-For set,
# as an anti-leeching measure. But the Codespaces proxy always sets that header,
# so we comment those two lines out or every request would get a 403.
sudo sed -i 's/RewriteCond.*X-Forwarded-For.*/#&/' \
    "$WEB/config/apache/standardebooks.test.conf"
sudo sed -i 's/RewriteCond.*CF-Connecting-IP.*/#&/' \
    "$WEB/config/apache/standardebooks.test.conf"

# The repo's Apache config sets UseCanonicalName On globally, which causes
# Apache to use the ServerName directive when constructing redirect URLs.
# We override it here so Apache uses the Host header instead.
echo "UseCanonicalName Off" \
    | sudo tee /etc/apache2/conf-available/codespaces.conf > /dev/null
sudo a2enconf codespaces

# Create a catch-all port-80 virtual host for Codespaces browser access.
# The repo's config only listens on port 443 with SSL, but Codespaces wraps
# forwarded ports in its own HTTPS, so we serve plain HTTP on port 80 and
# let Codespaces handle the SSL termination.
sudo tee /etc/apache2/sites-available/codespaces-catchall.conf > /dev/null <<'EOF'
<VirtualHost *:80>
    ServerName _
    ServerAlias *
    UseCanonicalName Off
    ProxyPreserveHost On

    DocumentRoot /standardebooks.org/web/www

    # Tell PHP the connection is HTTPS even though we're on port 80,
    # since Codespaces is handling SSL termination upstream.
    SetEnv HTTPS on

    <Directory /standardebooks.org/web/www>
        AllowOverride None
        Options None
        Require all granted
        CGIPassAuth on
    </Directory>

    <FilesMatch ".+\.php$">
        <If "-f %{REQUEST_FILENAME}">
            SetHandler "proxy:unix:/run/php/standardebooks.test.sock|fcgi://standardebooks.test"
            Header set Cache-Control "no-store"
        </If>
    </FilesMatch>

    <Proxy "fcgi://standardebooks.test">
        ProxySet connectiontimeout=5 timeout=240
    </Proxy>

    ErrorLog /var/log/local/error.log
    CustomLog /var/log/local/access.log combined
</VirtualHost>
EOF
sudo a2ensite codespaces-catchall

# ==============================================================================
echo "==> Configuring PHP-FPM..."
# ==============================================================================

# Create a placeholder secrets file if it doesn't exist
if [ ! -f "$WEB/config/php/fpm/standardebooks.test-secrets.ini" ]; then
    touch "$WEB/config/php/fpm/standardebooks.test-secrets.ini"
fi

sudo ln -sf "$WEB/config/php/fpm/standardebooks.test.ini" \
    "/etc/php/$PHP_VER/cli/conf.d/standardebooks.test.ini"
sudo ln -sf "$WEB/config/php/fpm/standardebooks.test-secrets.ini" \
    "/etc/php/$PHP_VER/cli/conf.d/standardebooks.test-secrets.ini"
sudo ln -sf "$WEB/config/php/fpm/standardebooks.test.ini" \
    "/etc/php/$PHP_VER/fpm/conf.d/standardebooks.test.ini"
sudo ln -sf "$WEB/config/php/fpm/standardebooks.test-secrets.ini" \
    "/etc/php/$PHP_VER/fpm/conf.d/standardebooks.test-secrets.ini"
sudo ln -sf "$WEB/config/php/fpm/standardebooks.test.conf" \
    "/etc/php/$PHP_VER/fpm/pool.d/standardebooks.test.conf"

# Create a prepend file that fixes $_SERVER['SERVER_NAME'] and $_SERVER['HTTP_HOST']
# to use the Codespaces hostname from the X-Forwarded-Host header.
# This is needed because the Codespaces proxy rewrites the Host header to
# localhost before it reaches Apache, so PHP would otherwise build all URLs
# with localhost as the hostname.
cat > /tmp/codespaces-prepend.php << 'PHPEOF'
<?php
if(isset($_SERVER['HTTP_X_FORWARDED_HOST'])){
    $_SERVER['SERVER_NAME'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
    $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
    $_SERVER['SERVER_PORT'] = '443';
}
PHPEOF
sudo mv /tmp/codespaces-prepend.php \
    "$WEB/config/php/fpm/codespaces-prepend.php"

# Write the auto_prepend_file setting to a Codespaces-only ini file,
# separate from the repo's ini files so it doesn't show up in git diff.
echo "auto_prepend_file = $WEB/config/php/fpm/codespaces-prepend.php" \
    | sudo tee "/etc/php/$PHP_VER/fpm/conf.d/codespaces.ini" > /dev/null

# ==============================================================================
echo "==> Configuring MariaDB..."
# ==============================================================================
sudo ln -sf "$WEB/config/mariadb/99-se.cnf" \
    /etc/mysql/mariadb.conf.d/99-se.cnf
# MariaDB ignores world-writable config files, so tighten the permissions.
sudo chmod 644 "$WEB/config/mariadb/99-se.cnf"

# ==============================================================================
echo "==> Creating users and groups..."
# ==============================================================================
sudo useradd -r se 2>/dev/null || true
sudo groupadd committers 2>/dev/null || true
sudo groupadd se-secrets 2>/dev/null || true
sudo usermod --append --groups committers,se-secrets se
sudo usermod --append --groups se-secrets www-data

# ==============================================================================
echo "==> Starting services..."
# ==============================================================================
sudo mkdir -p /run/php
sudo service mariadb start
sudo service "php${PHP_VER}-fpm" start
sudo service apache2 start

# ==============================================================================
echo "==> Setting up the SE database..."
# ==============================================================================
sudo mariadb < "$WEB/config/sql/se.sql"
sudo mariadb < "$WEB/config/sql/users.sql"
for f in "$WEB/config/sql/se/"*.sql; do
    sudo mariadb se < "$f"
done

# ==============================================================================
echo "==> Creating ebooks directory..."
# ==============================================================================
mkdir -p "$SITE/ebooks"

echo ""
echo "============================================================"
echo " Setup complete!"
echo " Open the Ports tab and click the globe icon next to port 80"
echo " to open the site in your browser."
echo "============================================================"
