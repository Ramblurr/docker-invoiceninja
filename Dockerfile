ARG PHP_VERSION=7.4
ARG BAK_STORAGE_PATH=/var/www/app/docker-backup-storage/
ARG BAK_PUBLIC_PATH=/var/www/app/docker-backup-public/

# Get Invoice Ninja and install nodejs packages
FROM --platform=$BUILDPLATFORM node:lts-alpine as build

# Download Invoice Ninja
ARG INVOICENINJA_VERSION
ADD https://github.com/invoiceninja/invoiceninja/tarball/v$INVOICENINJA_VERSION /tmp/ninja.tar.gz

# Extract Invoice Ninja
RUN mkdir -p /var/www/app \
    && tar --strip-components=1 -xf /tmp/ninja.tar.gz -C /var/www/app/ \
    && mkdir -p /var/www/app/public/logo /var/www/app/storage \
    && mv /var/www/app/.env.example /var/www/app/.env \
    && rm -rf /var/www/app/docs /var/www/app/tests

WORKDIR /var/www/app/

# Install node packages
ARG BAK_STORAGE_PATH
ARG BAK_PUBLIC_PATH
RUN --mount=target=/var/www/app/node_modules,type=cache \
    npm install --production \
    && npm run production \
    && mv /var/www/app/storage $BAK_STORAGE_PATH \
    && mv /var/www/app/public $BAK_PUBLIC_PATH  

# Prepare php image
FROM php:${PHP_VERSION}-fpm-alpine3.13 as prod

LABEL maintainer="David Bomba <turbo124@gmail.com>"

RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Install PHP extensions
# https://hub.docker.com/r/mlocati/php-extension-installer/tags
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
    bcmath \
    exif \
    gd \
    gmp \
    mysqli \
    opcache \
    pdo_mysql \
    zip \
    @composer \
    && rm /usr/local/bin/install-php-extensions

# Install chromium
RUN set -eux; \
    apk add --no-cache \
    supervisor \
    mysql-client \
    git \
    chromium \
    ttf-freefont

# Install gosu
ENV GOSU_VERSION 1.14
RUN set -eux; \
	\
	apk add --no-cache --virtual .gosu-deps \
		ca-certificates \
		dpkg \
		gnupg \
	; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
# clean up fetch dependencies
	apk del --no-network .gosu-deps; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true

# Copy files
COPY rootfs /

## Create user
ARG UID=1500
ARG GID=1500
ENV INVOICENINJA_USER invoiceninja
ENV INVOICENINJA_GROUP invoiceninja

RUN addgroup --gid=$GID -S "$INVOICENINJA_USER" \
    && adduser --uid=$UID \
    --disabled-password \
    --gecos "" \
    --home "/var/www/app" \
    --ingroup "$INVOICENINJA_GROUP" \
    "$INVOICENINJA_USER"

# Set up app
ARG INVOICENINJA_VERSION
ARG BAK_STORAGE_PATH
ARG BAK_PUBLIC_PATH
ENV INVOICENINJA_VERSION $INVOICENINJA_VERSION
ENV BAK_STORAGE_PATH $BAK_STORAGE_PATH
ENV BAK_PUBLIC_PATH $BAK_PUBLIC_PATH
COPY --from=build /var/www/app /var/www/app

WORKDIR /var/www/app

# Do not remove this ENV
ENV IS_DOCKER true
RUN /usr/local/bin/composer install --no-dev --quiet

# Override the environment settings from projects .env file
ENV APP_ENV production
ENV LOG errorlog
ENV SNAPPDF_EXECUTABLE_PATH /usr/bin/chromium-browser

ENTRYPOINT ["docker-gosu-entrypoint"]
CMD ["supervisord"]
