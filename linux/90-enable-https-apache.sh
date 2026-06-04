#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   sudo ./90-enable-https-apache.sh srv-web
#   sudo ./90-enable-https-apache.sh srv-zabbix
#   sudo ./90-enable-https-apache.sh srv-observium

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer en root."
  exit 1
fi

CN="${1:-$(hostname -f 2>/dev/null || hostname)}"

apt-get update
apt-get install -y apache2 openssl

mkdir -p /etc/ssl/localcerts

if [[ ! -f /etc/ssl/localcerts/server.key || ! -f /etc/ssl/localcerts/server.crt ]]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/C=FR/ST=Grand Est/L=Strasbourg/O=Formation/OU=TP Supervision/CN=$CN" \
    -keyout /etc/ssl/localcerts/server.key \
    -out /etc/ssl/localcerts/server.crt
fi

chmod 600 /etc/ssl/localcerts/server.key
chmod 644 /etc/ssl/localcerts/server.crt

a2enmod ssl headers rewrite >/dev/null

cat >/etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin admin@formation.lan
    DocumentRoot /var/www/html

    RewriteEngine On
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/?(.*) https://%{HTTP_HOST}/$1 [R=301,L]

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

cat >/etc/apache2/sites-available/default-ssl.conf <<'EOF'
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin admin@formation.lan
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/ssl/localcerts/server.crt
    SSLCertificateKeyFile /etc/ssl/localcerts/server.key

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/ssl_error.log
    CustomLog ${APACHE_LOG_DIR}/ssl_access.log combined
</VirtualHost>
</IfModule>
EOF

a2ensite default-ssl >/dev/null
apache2ctl configtest
systemctl reload apache2

ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

echo "OK: HTTPS auto-signé activé pour $CN."
