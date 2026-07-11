#!/usr/bin/env bash
# Automated smoke test for the zoneminder container.
# Builds the image, starts a mariadb sidecar on a shared docker network, runs
# zoneminder pointed at it and asserts that apache + the ZoneMinder web console
# come up and serve without PHP fatal errors.
#
# No host bind-mounts: the DB lives inside the sidecar container, and HTTP is
# spoken from inside the zoneminder container with a bash /dev/tcp helper
# (the apache2 base image ships no wget/curl).
set -e

IMG=zoneminder-test
CN=zoneminder-test-run
DB=zoneminder-test-db
NET=zoneminder-test-net

cleanup() {
  docker rm -f "$CN" >/dev/null 2>&1 || true
  docker rm -f "$DB" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "FAIL: $1"; exit 1; }

# http_get <container> <path> -> full HTTP response (headers + body) via /dev/tcp
http_get() {
  docker exec "$1" bash -c '
    exec 3<>/dev/tcp/127.0.0.1/80 || exit 1
    printf "GET '"$2"' HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3
    cat <&3
  '
}

# http_console <container> -> fetch /zm/ and follow ZoneMinder's first-run
# redirect (e.g. -> ?view=privacy) so we land on the real console HTML.
http_console() {
  local resp loc
  resp=$(http_get "$1" /zm/)
  loc=$(echo "$resp" | grep -i '^Location:' | head -1 | sed 's/^[Ll]ocation:[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r')
  if [ -n "$loc" ]; then
    case "$loc" in
      /*) http_get "$1" "$loc" ;;
      *)  http_get "$1" "/zm/$loc" ;;
    esac
  else
    echo "$resp"
  fi
}

echo ">> building image"
docker build -t "$IMG" .

echo ">> (re)creating docker network"
docker network rm "$NET" >/dev/null 2>&1 || true
docker network create "$NET" >/dev/null

echo ">> starting mariadb sidecar"
docker rm -f "$DB" >/dev/null 2>&1 || true
docker run -d --name "$DB" --network "$NET" \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=zm \
  -e MYSQL_USER=zmuser \
  -e MYSQL_PASSWORD=zmpass \
  mariadb --max-allowed-packet=64MB >/dev/null

echo ">> waiting for mariadb to accept connections (up to 60s)"
dbup=0
for _ in $(seq 1 30); do
  if docker exec "$DB" mariadb-admin ping -uzmuser -pzmpass >/dev/null 2>&1; then dbup=1; break; fi
  sleep 2
done
[ "$dbup" = 1 ] || fail "mariadb sidecar did not become ready in time"
echo "ok - mariadb ready"

echo ">> starting zoneminder"
docker rm -f "$CN" >/dev/null 2>&1 || true
docker run -d --name "$CN" --network "$NET" \
  --shm-size=2g \
  -e DISABLE_TLS=disable \
  -e ZM_DB_HOST="$DB" \
  -e ZM_DB_NAME=zm \
  -e ZM_DB_USER=zmuser \
  -e ZM_DB_PASS=zmpass \
  "$IMG" >/dev/null

echo ">> waiting for apache to listen on :80 (up to 90s)"
up=0
for _ in $(seq 1 45); do
  if docker exec "$CN" bash -c 'exec 3<>/dev/tcp/127.0.0.1/80' 2>/dev/null; then up=1; break; fi
  sleep 2
done
[ "$up" = 1 ] || fail "apache did not start listening on :80 in time"
echo "ok - apache listening on :80"

echo ">> assert: container is running"
[ "$(docker inspect -f '{{.State.Running}}' "$CN")" = true ] || fail "container not running"
echo "ok - container running"

echo ">> waiting for the ZoneMinder console to serve (db init is slow, up to 120s)"
zmup=0
for _ in $(seq 1 60); do
  if http_console "$CN" 2>/dev/null | grep -q 'ZoneMinder'; then zmup=1; break; fi
  sleep 2
done
[ "$zmup" = 1 ] || fail "ZoneMinder console did not serve HTML in time"
echo "ok - ZoneMinder console responding"

echo ">> assert: GET / redirects (302) to zm/"
root=$(http_get "$CN" /)
echo "$root" | head -1 | grep -q '302' || fail "GET / did not return 302 (got: $(echo "$root" | head -1))"
echo "$root" | grep -qi '^Location:.*zm/' || fail "GET / 302 has no Location: zm/ header"
echo "ok - GET / -> 302 Location: zm/"

echo ">> assert: the ZoneMinder web console serves HTML containing ZoneMinder"
# GET /zm/ lands on the console; on a fresh install it first bounces through
# ?view=privacy, so follow that one redirect before inspecting the body.
zm=$(http_console "$CN")
echo "$zm" | head -1 | grep -q '200' || fail "console did not return 200 (got: $(echo "$zm" | head -1))"
echo "$zm" | grep -q 'ZoneMinder' || fail "console body does not contain 'ZoneMinder'"
echo "ok - console serves ZoneMinder HTML ($(echo "$zm" | grep -io '<title>[^<]*</title>' | head -1))"

# The very first requests during db bootstrap can log a transient logger.php
# fatal (config constants not defined yet); that window is over once the
# console serves above. Truncate the log, hit the console fresh and assert the
# steady-state console renders without any PHP fatal.
echo ">> assert: no PHP Fatal errors serving the console (steady state)"
docker exec "$CN" sh -c ': > /var/log/apache2/error.log' 2>/dev/null || true
http_console "$CN" >/dev/null 2>&1
http_get "$CN" '/zm/?view=console' >/dev/null 2>&1
sleep 2
logs=$( { docker exec "$CN" cat /var/log/apache2/error.log 2>/dev/null; docker logs "$CN" 2>&1; } || true )
echo "$logs" | grep -i 'PHP Fatal' && fail "PHP Fatal error found while serving the console" || true
echo "ok - no PHP Fatal errors"

echo ""
echo "ALL TESTS PASSED"
