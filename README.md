# docker-invoiceninja

Based on the official [invoiceninja/dockerfiles](https://github.com/invoiceninja/dockerfiles).

Withs some custom changes:

* image runs as root, but uses [gosu](https://github.com/tianon/gosu) to step-down privs before running the app
* before stepping down, the root user changes the `invoiceninja` user uid and gid according to the passed env vars

This makes using invoiceninja easier with NFS.

## Usage

```console
$ podman container run \
  --rm \
  -d \
  --replace \
  --name invoiceninja-app \
  --memory 2048M \
  --volume /srv/services/invoiceninja/data/public:/var/www/app/public:z \
  --volume /srv/services/invoiceninja/data/storage:/var/www/app/storage:z \
  --env PUID=1000 \
  --env PGID=1000 \
  --env DB_STRICT=false \
  --env DB_HOST=yourdb.host \
  --env DB_USERNAME_FILE=/run/secrets/invoiceninja-db-username \
  --env DB_DATABASE=invoiceninja \
  --env DB_PASSWORD_FILE=/run/secrets/invoiceninja-db-password \
  --env TRUSTED_PROXIES=* \
  --env PDF_GENERATOR=snappdf \
  --env APP_DEBUG=false \
  --env REQUIRE_HTTPS=false \
  --env PHANTOMJS_PDF_GENERATION=false \
  --env APP_KEY_FILE=/run/secrets/invoiceninja-app-key \
  --env APP_URL=https://yourdomain.com \
  --env QUEUE_CONNECTION=database \
  --env MAIL_MAILER=smtp \
  --env MAIL_HOST=smtp.yourhost.com \
  --env MAIL_PASSWORD_FILE=/run/secrets/invoiceninja-mail-password \
  --env MAIL_USERNAME=user@yourdomain.com \
  --env MAIL_PORT=465 \
  --env "MAIL_FROM_NAME=Your Name" \
  --env MAIL_FROM_ADDRESS=notifications@yourdomain.com \
  --env MAIL_ENCRYPTION=tls \
  --secret invoiceninja-db-username \
  --secret invoiceninja-db-password \
  --secret invoiceninja-mail-password \
  --secret invoiceninja-app-key \
  --label io.containers.autoupdate=image \
  docker.io/ramblurr/invoiceninja:5
  ```
