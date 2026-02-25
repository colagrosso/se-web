FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y \
    git \
    curl \
    sudo \
    composer \
    php-fpm \
    php-cli \
    php-gd \
    php-xml \
    php-apcu \
    php-mbstring \
    php-intl \
    php-curl \
    php-zip \
    php-mysql \
    php-mailparse \
    apache2 \
    apache2-utils \
    libfcgi0ldbl \
    task-spooler \
    ipv6calc \
    mariadb-server \
    attr \
    libapache2-mod-xsendfile \
    libimage-exiftool-perl \
    librsvg2-bin \
    python3 \
    python3-pip \
    python3-venv \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Create the codespace user that Codespaces expects
RUN useradd -m -s /bin/bash codespace \
    && echo "codespace ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Pre-create the site directory so the volume mount works cleanly
RUN mkdir -p /standardebooks.org && chown codespace: /standardebooks.org

RUN for f in /etc/php/*/fpm/php.ini; do \
        echo "opcache.validate_timestamps=1" >> "$f"; \
        echo "opcache.revalidate_freq=0" >> "$f"; \
    done

USER codespace
