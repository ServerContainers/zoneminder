# zoneminder - (ghcr.io/servercontainers/zoneminder) (+ optional tls) on debian, apache2 [x86 + arm]

_maintained by ServerContainers_

## What is it

This Dockerfile (available as ___ghcr.io/servercontainers/zoneminder___) gives you a ready to use zoneminder installation with optional tls.

Note: This container only supports `mysql` / `mariadb` database servers.
There is no internal mysql-server available - so you need to setup a seconds container for that (take a look at `docker-compose.yml`)

View in Docker Registry [ghcr.io/servercontainers/zoneminder](https://ghcr.io/servercontainers/zoneminder)

View in GitHub [ServerContainers/docker-zoneminder](https://github.com/ServerContainers/docker-zoneminder)

This Dockerfile is based on the [ghcr.io/servercontainers/apache2-ssl-secure](https://ghcr.io/servercontainers/apache2-ssl-secure/) `debian:bullseye` based image.

## Build & Versioning

You can specify `DOCKER_REGISTRY` environment variable (for example `my.registry.tld`)
and use the build script to build the main container and it's variants for _x86_64, arm64 and arm_

You'll find all images tagged like `d11.2-a1.18.0-6.1-zm1.36.0` which means `d<debian version>-a<apache version (with some esacped chars)>-zm<zoneminder version (with some esacped chars)>`.
This way you can pin your installation/configuration to a certian version. or easily roll back if you experience any problems
(don't forget to open a issue in that case ;D).

To build a `latest` tag run `./build.sh release`

## Changelogs

* 2023-03-20
    * github action to build container
    * implemented ghcr.io as new registry
    * moved from `MarvAmBass` to `ServerContainers`
* 2021-09-06
    * increased `shm_size` for more cameras
* 2021-08-27
    * small fixes
    * added this repo to container
* 2021-08-09
    * initial commit
    * healthchecks
    * multiarch build

## How to use

This container needs a database, so take a look at the `docker-compose.yml`

## Environment variables and defaults

* __ZM\_DB\_HOST__
 * host of mysql db
 * default: `db`

* __ZM\_DB\_NAME__
 * name of the mysql zoneminder database
 * default: `zm`

* __ZM\_DB\_USER__
 * username of the mysql database for zoneminder
 * default: `zmuser`

* __ZM\_DB\_PASS__
 * username of the mysql database for zoneminder
 * default: `zmpass`

* __ZM\_DB\_SSL\_CA\_CERT__
 * default: _not set_

* __ZM\_DB\_SSL\_CLIENT\_KEY__
 * default: _not set_

* __ZM\_DB\_SSL\_CLIENT\_CERT__
 * default: _not set_

### BASEIMAGE: Environment variables and defaults

* __DISABLE\_TLS__
 * default: not set - if set yo any value `https` and the `HSTS_HEADERS_*` will be disabled

* __HSTS\_HEADERS\_ENABLE__
 * default: not set - if set to any value the HTTP Strict Transport Security will be activated on SSL Channel

* __HSTS\_HEADERS\_ENABLE\_NO\_SUBDOMAINS__
 * default: not set - if set together with __HSTS\_HEADERS\_ENABLE__ and set to any value the HTTP Strict Transport Security will be deactivated on subdomains

