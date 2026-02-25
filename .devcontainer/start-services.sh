#!/bin/bash
# Run this whenever you resume a codespace after it's been paused.
# Services stop when the codespace is suspended.

PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
sudo service mariadb start
sudo service "php${PHP_VER}-fpm" start
sudo service apache2 start
echo "Services started."
