#!/bin/bash
echo 'SHOW TABLES;' | mysql -h db -u zmuser -pzmpass zm 2>/dev/null >/dev/null || exit 1