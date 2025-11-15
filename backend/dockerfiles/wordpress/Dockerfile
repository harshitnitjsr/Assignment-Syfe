# Production-grade WordPress with PHP-FPM
FROM php:8.1-fpm-alpine

# Install system and PHP build dependencies
RUN set -eux; \
    apk add --no-cache \
        bash \
        curl \
        wget \
        less \
        vim \
        mariadb-client \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        freetype-dev \
        libzip-dev \
        icu-dev \
        imagemagick-dev \
        imagemagick \
        ghostscript-fonts \
        $PHPIZE_DEPS \
        linux-headers \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        mysqli \
        pdo \
        pdo_mysql \
        opcache \
        zip \
        exif \
        intl \
        bcmath \
    && pecl install imagick redis \
    && docker-php-ext-enable imagick redis \
    && apk del --no-cache linux-headers $PHPIZE_DEPS

# Install WP-CLI
RUN set -eux; \
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
    chmod +x wp-cli.phar; \
    mv wp-cli.phar /usr/local/bin/wp

# PHP configuration (must exist in build context)
COPY php.ini /usr/local/etc/php/conf.d/wordpress.ini
COPY php-fpm.conf /usr/local/etc/php-fpm.d/zz-wordpress.conf
    
# Ensure php-fpm log directory exists for access.log and slowlog
RUN mkdir -p /var/log/php-fpm \
    && chown -R www-data:www-data /var/log/php-fpm

# Download and install WordPress
ARG WORDPRESS_VERSION=6.4
WORKDIR /tmp
RUN set -eux; \
    wget https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz; \
    tar -xzf wordpress-${WORDPRESS_VERSION}.tar.gz; \
    mkdir -p /var/www/html; \
    mv wordpress/* /var/www/html/; \
    rm -rf wordpress wordpress-${WORDPRESS_VERSION}.tar.gz

# WordPress base permissions
RUN set -eux; \
    chown -R www-data:www-data /var/www/html; \
    find /var/www/html -type d -exec chmod 755 {} \; ; \
    find /var/www/html -type f -exec chmod 644 {} \;

# WordPress configuration (must exist in build context)
COPY wp-config-docker.php /var/www/html/wp-config.php
RUN chown www-data:www-data /var/www/html/wp-config.php

# Create uploads directory
RUN set -eux; \
    mkdir -p /var/www/html/wp-content/uploads; \
    chown -R www-data:www-data /var/www/html/wp-content/uploads

WORKDIR /var/www/html

# Healthcheck script (must exist in build context)
COPY php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck
RUN chmod +x /usr/local/bin/php-fpm-healthcheck

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php-fpm-healthcheck || exit 1

EXPOSE 9000

CMD ["php-fpm"]
