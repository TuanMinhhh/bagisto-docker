# main image
FROM php:8.3-fpm

# installing main dependencies
RUN apt-get update && apt-get install -y \
    git \
    ffmpeg \
    procps

# installing unzip dependencies
RUN apt-get install -y \
    libzip-dev \
    zlib1g-dev \
    unzip

# gd extension configure and install
RUN apt-get install -y \
    libfreetype6-dev \
    libicu-dev \
    libgmp-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && docker-php-ext-install gd

# imagick extension configure and install
RUN apt-get install -y libmagickwand-dev \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# intl extension configure and install
RUN docker-php-ext-configure intl && docker-php-ext-install intl

# other extensions install
RUN docker-php-ext-install bcmath calendar exif gmp mysqli opcache pdo pdo_mysql zip

# OPcache + realpath cache: large win for Bagisto’s many PHP files (especially on slow bind mounts).
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=32'; \
    echo 'opcache.max_accelerated_files=30000'; \
    echo 'opcache.validate_timestamps=1'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'realpath_cache_size=8192K'; \
    echo 'realpath_cache_ttl=600'; \
    } > /usr/local/etc/php/conf.d/docker-php-performance.ini

# installing composer
COPY --from=composer:2.7 /usr/bin/composer /usr/local/bin/composer

# installing node js
COPY --from=node:23 /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node:23 /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# installing global node dependencies
RUN npm install -g npx
RUN npm install -g laravel-echo-server

# arguments (defaults help Windows hosts where USER is unset)
ARG container_project_path
ARG uid=1000
ARG user=developer

# copy php-fpm pool configuration
COPY ./.configs/nginx/pools/www.cnf /usr/local/etc/php-fpm.d/www.conf

# adding user
RUN useradd -G www-data,root -u $uid -d /home/$user $user
RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

# setting up project from `src` folder
RUN chmod -R 775 $container_project_path
RUN chown -R $user:www-data $container_project_path

# changing user
USER $user

# setting work directory
WORKDIR $container_project_path
