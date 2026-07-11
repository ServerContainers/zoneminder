FROM ghcr.io/servercontainers/apache2-ssl-secure

RUN apt-get -q -y update && \
    apt-get -q -y install apt-transport-https gnupg wget && \
    \
    mkdir -p /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/zoneminder.asc https://zmrepo.zoneminder.com/debian/archive-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/zoneminder.asc] https://zmrepo.zoneminder.com/debian/release-1.38 trixie/' >> /etc/apt/sources.list && \
    \
    apt-get -q -y update && \
    apt-get -q -y install zoneminder && \
    apt-get -q -y clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    \
    a2enconf zoneminder && \
    a2enmod rewrite && \
    \
    sed -i 's/ZM_DB_HOST=.*/ZM_DB_HOST=db/g' /etc/zm/zm.conf

COPY scripts/healthchecks.d/* /container/scripts/healthchecks.d/

COPY config/www/index.php /var/www/html/index.php
COPY config/runit/zoneminder /container/config/runit/zoneminder

COPY . /container-2