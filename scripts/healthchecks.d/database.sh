#!/bin/bash
echo 'SHOW TABLES;' | mysql -h "$ZM_DB_HOST" -u "$ZM_DB_USER" -p"$ZM_DB_PASS" "$ZM_DB_NAME" 2>/dev/null >/dev/null || exit 1
