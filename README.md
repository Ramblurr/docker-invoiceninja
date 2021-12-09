# docker-invoiceninja

Custom build of Invoice Ninja v5.

Based on https://github.com/invoiceninja/dockerfiles

## Differences

* image runs as root, but uses [gosu](https://github.com/tianon/gosu) to step-down privs before running the app
* before stepping down, the root user changes the `invoiceninja` user uid and gid according to the passed env vars


This makes using invoiceninja easier with NFS.
