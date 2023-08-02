FROM php:8.2-cli

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC
ENV GOSU_UID=1000
ENV GOSU_GID=1000
ENV GOSU_ENABLED=0
ENV COMPOSER_HOME=/.composer

RUN apt-get update && \
    apt-get install -y zlib1g-dev libpng-dev libjpeg-dev libfreetype-dev libssl-dev libpq-dev libcurl4-openssl-dev  \
        libmemcached-dev libldap-dev \
        libc-client-dev libkrb5-dev libxml2-dev libzip-dev libbz2-dev libffi-dev libxslt1-dev libmagickwand-dev \
        gosu libcap2-bin acl git && \
    docker-php-source extract && \
    pecl install msgpack && pecl install xdebug && pecl install igbinary && pecl install pcov && \
    docker-php-ext-install sockets && \
    cd /usr/src/php/ext && \
    pecl bundle redis && \
    pecl bundle memcached && \
    pecl bundle imagick && \
    pecl bundle swoole && \
    docker-php-ext-configure redis --enable-redis-igbinary --enable-redis-lzf && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure memcached --with-libmemcached-dir --with-zlib-dir --with-system-fastlz=no \
        --enable-memcached-igbinary=yes --enable-memcached-msgpack=yes --enable-memcached-json=yes  \
        --enable-memcached-protocol=no --enable-memcached-sasl=yes --enable-memcached-session=yes && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-configure imagick && \
    docker-php-ext-configure swoole --enable-sockets=yes --enable-openssl=yes --enable-mysqlnd=yes --enable-swoole-curl=yes --enable-cares=no --enable-brotli=yes

RUN \
    docker-php-ext-enable pcov igbinary msgpack && \
    for ext in redis gd memcached pdo_pgsql ffi gettext ldap \
                       pcntl shmop sysvmsg sysvsem sysvshm xsl opcache imagick \
                       imap intl soap bcmath calendar exif mysqli pdo_mysql pgsql zip swoole; do \
      docker-php-ext-install $ext || exit 1; done && \
    mkdir "$COMPOSER_HOME" && setfacl -m d:m:rwx "$COMPOSER_HOME" && \
    curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer && \
    pear install PHP_CodeSniffer

# SWOOLE
RUN cd /usr/src/php/ext && \
    pecl bundle swoole && \
    docker-php-ext-configure swoole --enable-sockets=yes --enable-openssl=yes --enable-mysqlnd=yes --enable-swoole-curl=yes --enable-cares=no --enable-brotli=yes && \
    docker-php-ext-install swoole

## CLEANUP
RUN \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    docker-php-source delete

RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/php

COPY docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
COPY php.ini /usr/local/etc/php/php.ini
COPY phpcs.xml /var/www/phpcs.xml
RUN chmod +x /usr/local/bin/docker-php-entrypoint

WORKDIR /var/www/html
ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php", "-a"]
