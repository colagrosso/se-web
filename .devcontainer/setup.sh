#!/bin/bash
set -e

REPO="/workspaces/se-web"
SITE="/standardebooks.org"
WEB="$SITE/web"

echo "==> Setting up directory structure..."
sudo mkdir -p "$SITE"
sudo ln -sfn "$REPO" "$WEB"
sudo chown -R codespace: "$SITE"
sudo mkdir -p /var/log/local
sudo chown -R codespace: /var/log/local

echo "==> Installing Composer dependencies..."
cd "$WEB"
composer install --no-interaction

echo "==> Setting up Python/SE toolset..."
python3 -m venv "$WEB/.venv"
source "$WEB/.venv/bin/activate"
pip3 install --quiet standardebooks
deactivate

echo "==> Creating self-signed SSL cert (needed by the existing Apache config)..."
mkdir -p "$WEB/config/ssl"
openssl req -x509 -nodes -days 99999 -newkey rsa:4096 \
    -subj "/CN=standardebooks.test" \
    -keyout "$WEB/config/ssl/standardebooks.test.key" \
    -sha256 \
    -out "$WEB/config/ssl/standardebooks.test.crt" 2>/dev/null

echo "==> Enabling Apache modules..."
sudo a2enmod headers expires ssl rewrite proxy proxy_fcgi xsendfile

echo "==> Wiring up Apache for standardebooks.test (existing config)..."
sudo ln -sf "$WEB/config/apache/standardebooks.test.conf" \
    /etc/apache2/sites-available/standardebooks.test.conf
sudo a2ensite standardebooks.test

echo "==> Adding catch-all port-80 virtual host for Codespaces browser access..."
sudo tee /etc/apache2/sites-available/codespaces-catchall.conf > /dev/null <<'EOF'
# This catch-all VirtualHost lets the Codespaces-forwarded URL work in your
# Chromebook browser. Codespaces wraps port 80 in its own HTTPS automatically.
<VirtualHost *:80>
    ServerName _
    ServerAlias *
    UseCanonicalName Off

    DocumentRoot /standardebooks.org/web/www

    SetEnv HTTPS on

    <Directory /standardebooks.org/web/www>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/standardebooks.test.sock|fcgi://localhost"
    </FilesMatch>

    ErrorLog /var/log/local/error.log
    CustomLog /var/log/local/access.log combined
</VirtualHost>
EOF
sudo a2ensite codespaces-catchall
sudo a2dissite 000-default || true

echo "==> Wiring up PHP-FPM..."
# Create a placeholder secrets file if it doesn't exist
if [ ! -f "$WEB/config/php/fpm/standardebooks.test-secrets.ini" ]; then
    touch "$WEB/config/php/fpm/standardebooks.test-secrets.ini"
fi

PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
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

echo "auto_prepend_file = /standardebooks.org/web/config/php/fpm/codespaces-prepend.php" \
    | sudo tee /etc/php/$PHP_VER/fpm/conf.d/codespaces.ini

echo "==> Wiring up MariaDB..."
sudo ln -sf "$WEB/config/mariadb/99-se.cnf" \
    /etc/mysql/mariadb.conf.d/99-se.cnf
sudo chmod 644 "$WEB/config/mariadb/99-se.cnf"

echo "==> Creating users and groups..."
sudo useradd -r se 2>/dev/null || true
sudo groupadd committers 2>/dev/null || true
sudo groupadd se-secrets 2>/dev/null || true
sudo usermod --append --groups committers,se-secrets se
sudo usermod --append --groups se-secrets www-data

echo "==> Starting services (no systemd in containers, so starting directly)..."
sudo mkdir -p /run/php
sudo service mariadb start
sudo service "php${PHP_VER}-fpm" start
sudo service apache2 start

echo "==> Setting up the SE database..."
sudo mariadb < "$WEB/config/sql/se.sql"
sudo mariadb < "$WEB/config/sql/users.sql"
for f in "$WEB/config/sql/se/"*.sql; do
    sudo mariadb se < "$f"
done

echo "==> Creating ebooks directory..."
mkdir -p "$SITE/ebooks"

echo ""
echo "============================================================"
echo " Setup complete!"
echo " The site should now be accessible via the forwarded port."
echo " Look for port 80 in the Codespaces 'Ports' tab."
echo "============================================================"
