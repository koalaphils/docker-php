ARG PHP_VERSION=8
FROM php:${PHP_VERSION}-cli AS builder

ENV DEBIAN_FRONTEND=noninteractive
# Dependencies for building PHP extensions
# Add dependencies for PIE
ENV PHPIZE_DEPS="${PHPIZE_DEPS} autoconf automake build-essential gcc git libtool m4 make"

# Copy PIE and Composer binaries
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --link --from=composer/composer /usr/bin/composer /usr/local/bin/composer
COPY --link --from=ghcr.io/php/pie:bin /pie /usr/bin/pie

# Install PHP extension build dependencies
RUN --mount=type=secret,id=github_token,env=GITHUB_TOKEN set -eux; \
    composer config --global github-oauth.github.com $GITHUB_TOKEN; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        libicu-dev \
        libmagickcore-dev \
        libmagickwand-dev \
        libmemcached-dev \
        libmsgpack-dev \
        libpng-dev \
        libssl-dev \
        `apt-cache pkgnames libavif | grep dev | sort | head -1` \
        `apt-cache pkgnames libc-ares | grep dev | sort | head -1` \
        `apt-cache pkgnames libc6 | grep dev | sort | head -1` \
        `apt-cache pkgnames libfreetype | grep dev | sort -V | head -1` \
        `apt-cache pkgnames libjpeg | grep dev | sort -V | head -1` \
        `apt-cache pkgnames libmcrypt | grep dev | sort | head -1` \
        `apt-cache pkgnames libmongo | grep dev | sort | head -1` \
        `apt-cache pkgnames librabbitmq | grep dev | sort -V | head -1` \
        `apt-cache pkgnames libsqlite3 | grep dev | sort -V | head -1` \
        `apt-cache pkgnames libwebp | grep dev | sort -V | head -1` \
        `apt-cache pkgnames libxsl | grep dev | sort -V | head -1` \
        `apt-cache pkgnames libzip | grep dev | sort | head -1` \
        `apt-cache pkgnames licurl4 | grep dev | grep openssl | sort -V` \
        `apt-cache pkgnames unixodbc | grep dev | sort -V | head -1` \
        `apt-cache pkgnames zlib | grep dev | sort -V | head -1` \
    && update-ca-certificates; \
    export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
    ; \
\
# Install PHP extensions built into the official image \
    docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype --with-avif; \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        dba \
        gd \
        gettext \
        intl \
        mysqli \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_sqlite \
        sockets \
        xsl \
        zip; \
    \
# Install PHP extensions from source using PECL \
    pecl install --onlyreqdeps --nobuild igbinary; \
        cd "$(pecl config-get temp_dir)/igbinary"; \
        phpize; \
        ./configure; \
        make && make test && make install && make clean || exit 1; \
        cd -; \
        docker-php-ext-enable --ini-name 0-docker-php-ext-igbinary.ini igbinary; \
    pecl install --onlyreqdeps --nobuild msgpack; \
        cd "$(pecl config-get temp_dir)/msgpack"; \
        phpize; \
        ./configure; \
        make && make test && make install && make clean || exit 1; \
        cd -; \
        docker-php-ext-enable --ini-name 0-docker-php-ext-msgpack.ini msgpack; \
    pecl install --onlyreqdeps --nobuild amqp; \
        cd "$(pecl config-get temp_dir)/amqp"; \
        phpize; \
        ./configure; \
        make && make test && make install && make clean || exit 1; \
        cd -; \
        docker-php-ext-enable amqp; \
    pecl install --onlyreqdeps --nobuild sqlsrv; \
        cd "$(pecl config-get temp_dir)/sqlsrv"; \
        phpize; \
        ./configure; \
        make && make test && make install && make clean || exit 1; \
        cd -; \
        docker-php-ext-enable sqlsrv; \
    pecl install --onlyreqdeps --nobuild pdo_sqlsrv; \
        cd "$(pecl config-get temp_dir)/pdo_sqlsrv"; \
        phpize; \
        ./configure; \
        make && make test && make install && make clean || exit 1; \
        cd -; \
        docker-php-ext-enable pdo_sqlsrv; \
    pecl install --onlyreqdeps --nobuild xhprof; \
        cd "$(pecl config-get temp_dir)/xhprof/extension"; \
        phpize; \
        ./configure; \
        make && make test && make install && make clean || exit 1; \
        cd -; \
        docker-php-ext-enable xhprof; \
\
# Install additional PHP extensions using PIE for easier management and to get the latest stable versions \
    pie install --skip-enable-extension apcu/apcu  && \
    pie install --skip-enable-extension imagick/imagick && \
    pie install --skip-enable-extension mongodb/mongodb-extension && \
    pie install --skip-enable-extension nikic/php-ast  && \
    pie install --skip-enable-extension osmanov/pecl-ev  && \
#    pie install --skip-enable-extension pdezwart/php-amqp && \
    pie install --skip-enable-extension pecl/mcrypt  && \
    pie install --skip-enable-extension pecl/pcov  && \
    pie install --skip-enable-extension php-memcached/php-memcached --enable-memcached-json --enable-memcached-igbinary --enable-memcached-msgpack  && \
    pie install --skip-enable-extension phpredis/phpredis --enable-redis-igbinary --enable-redis-msgpack  && \
    pie install --skip-enable-extension supermetrics/jsonpath && \
    pie install --skip-enable-extension swoole/swoole  && \
    pie install --skip-enable-extension xdebug/xdebug  && \
    docker-php-ext-enable  \
#      amqp \
      apcu \
      ast \
      ev \
      imagick \
      jsonpath \
      mcrypt \
      memcached \
      mongodb \
      pcov \
      redis \
      swoole \
      xdebug  || { echo "Could not enable some extensions"; exit 1; }; \
    \
# check all installed extensions \
    pie show --all;