#!/usr/bin/env bash
set -Eeuo pipefail

# VM cible : srv-observium / 192.168.1.13
# Services : Observium Community + Apache + MariaDB + SNMP tools

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer en root ou sudo."
  exit 1
fi

OBS_DB_PASS="${OBS_DB_PASS:-Observium1!}"
OBS_ADMIN_PASS="${OBS_ADMIN_PASS:-Observium1!}"
OBS_DEVICE="${OBS_DEVICE:-srv-web}"
OBS_COMMUNITY="${OBS_COMMUNITY:-public}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/9] Pré-requis Observium"
apt-get update
apt-get install -y \
  apache2 mariadb-server \
  php php-cli libapache2-mod-php php-mysql php-gd php-json php-mbstring php-snmp php-xml php-curl php-zip \
  snmp snmpd fping rrdtool graphviz imagemagick whois mtr-tiny nmap ipmitool \
  python3-pymysql python3-dotenv curl wget unzip tar ufw

echo "[2/9] Téléchargement Observium Community"
mkdir -p /opt
cd /opt

if [[ ! -d /opt/observium ]]; then
  wget -O /tmp/observium-community-latest.tar.gz http://www.observium.org/observium-community-latest.tar.gz
  tar zxvf /tmp/observium-community-latest.tar.gz -C /opt
fi

cd /opt/observium

echo "[3/9] Configuration base MariaDB"
systemctl enable --now mariadb

mysql <<SQL
CREATE DATABASE IF NOT EXISTS observium DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'observium'@'localhost' IDENTIFIED BY '${OBS_DB_PASS}';
GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "[4/9] Configuration Observium"
if [[ ! -f /opt/observium/config.php ]]; then
  cp /opt/observium/config.php.default /opt/observium/config.php
fi

sed -i "s/^\$config\['db_user'\].*/\$config['db_user'] = 'observium';/" /opt/observium/config.php
sed -i "s/^\$config\['db_pass'\].*/\$config['db_pass'] = '${OBS_DB_PASS}';/" /opt/observium/config.php
sed -i "s/^\$config\['db_name'\].*/\$config['db_name'] = 'observium';/" /opt/observium/config.php

grep -q "fping" /opt/observium/config.php || cat >>/opt/observium/config.php <<'EOF'

// Chemins Debian
$config['fping'] = "/usr/bin/fping";
$config['fping6'] = "/usr/bin/fping6";
EOF

echo "[5/9] Initialisation schéma Observium"
if [[ -x /opt/observium/discovery.php ]]; then
  /opt/observium/discovery.php -u || true
fi

echo "[6/9] Permissions"
mkdir -p /opt/observium/{logs,rrd}
chown -R www-data:www-data /opt/observium/logs /opt/observium/rrd
chown -R www-data:www-data /opt/observium/html

echo "[7/9] Apache /observium"
cat >/etc/apache2/sites-available/observium.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin admin@formation.lan
    DocumentRoot /var/www/html

    Alias /observium /opt/observium/html

    <Directory /opt/observium/html>
        Options FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/observium_error.log
    CustomLog ${APACHE_LOG_DIR}/observium_access.log combined
</VirtualHost>
EOF

a2enmod rewrite php* >/dev/null 2>&1 || a2enmod rewrite >/dev/null
a2ensite observium >/dev/null
apache2ctl configtest
systemctl enable --now apache2
systemctl reload apache2

echo "[8/9] Utilisateur admin + cron"
if [[ -x /opt/observium/adduser.php ]]; then
  /opt/observium/adduser.php admin "${OBS_ADMIN_PASS}" 10 || true
fi

cat >/etc/cron.d/observium <<'EOF'
# Observium poller/discovery
*/5 * * * * root /opt/observium/poller-wrapper.py 4 >> /dev/null 2>&1
33 */6 * * * root /opt/observium/discovery.php -h all >> /dev/null 2>&1
13 5 * * * root /opt/observium/discovery.php -h new >> /dev/null 2>&1
EOF

echo "[9/9] Ajout device srv-web via SNMP si disponible"
if ping -c 1 -W 1 "${OBS_DEVICE}" >/dev/null 2>&1; then
  if snmpwalk -v2c -c "${OBS_COMMUNITY}" "${OBS_DEVICE}" sysName.0 >/dev/null 2>&1; then
    /opt/observium/add_device.php "${OBS_DEVICE}" "${OBS_COMMUNITY}" v2c || true
    /opt/observium/discovery.php -h all || true
    /opt/observium/poller.php -h all || true
  else
    echo "WARN: SNMP ne répond pas sur ${OBS_DEVICE}. Lance d'abord le script srv-web puis relance :"
    echo "      /opt/observium/add_device.php ${OBS_DEVICE} ${OBS_COMMUNITY} v2c"
  fi
else
  echo "WARN: ${OBS_DEVICE} non joignable."
fi

ufw allow 80/tcp comment 'HTTP Observium'
ufw allow 443/tcp comment 'HTTPS Observium'
ufw allow from 192.168.1.0/24 to any port 161 proto udp comment 'SNMP LAN'
ufw --force enable

echo
echo "OK: srv-observium prêt."
echo "Interface : http://192.168.1.13/observium"
echo "Compte Observium : admin / ${OBS_ADMIN_PASS}"
