#!/bin/bash
chmod -R 777 /var/cache/zoneminder/events
/usr/bin/zmpkg.pl status | grep running 2>/dev/null >/dev/null || exit 1