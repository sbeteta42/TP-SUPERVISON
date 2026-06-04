#!/usr/bin/env bash
set -Eeuo pipefail

# VM cible : srv-zabbix / 192.168.1.11
# Services : Zabbix Server 7.0 LTS, Frontend Apache/PHP, MariaDB, Agent

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer en root ou sudo."
  exit 1
fi

ZABBIX_DB_PASS="${ZABBIX_DB_PASS:-ZabbixPass1!}"
PHP_TZ="${PHP_TZ:-Europe/Paris}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/8] Pré-requis"
apt-get update
apt-get install -y ca-certificates curl wget gnupg lsb-release mariadb-server apache2 ufw

echo "[2/8] Dépôt Zabbix 7.0 LTS"
ZBX_DEB="/tmp/zabbix-release.deb"
if ! wget -q -O "$ZBX_DEB" "https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian12_all.deb"; then
  wget -q -O "$ZBX_DEB" "https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1+debian12_all.deb"
fi
dpkg -i "$ZBX_DEB"
apt-get update

echo "[3/8] Installation Zabbix Server + Frontend + Agent"
apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf \
  zabbix-sql-scripts zabbix-agent zabbix-get

echo "[4/8] Création base Zabbix"
systemctl enable --now mariadb

mysql <<SQL
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${ZABBIX_DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
SQL

TABLE_COUNT="$(mysql -N -B -uzabbix -p"${ZABBIX_DB_PASS}" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix';" 2>/dev/null || echo 0)"
if [[ "$TABLE_COUNT" == "0" ]]; then
  echo "[5/8] Import schéma Zabbix, cela peut prendre quelques minutes"
  zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${ZABBIX_DB_PASS}" zabbix
else
  echo "[5/8] Schéma Zabbix déjà présent, import ignoré"
fi

mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;" || true

echo "[6/8] Configuration Zabbix Server"
cp -a /etc/zabbix/zabbix_server.conf "/etc/zabbix/zabbix_server.conf.bak.$(date +%F-%H%M%S)"
sed -i "s/^# DBPassword=.*/DBPassword=${ZABBIX_DB_PASS}/" /etc/zabbix/zabbix_server.conf
grep -q "^DBPassword=" /etc/zabbix/zabbix_server.conf || echo "DBPassword=${ZABBIX_DB_PASS}" >> /etc/zabbix/zabbix_server.conf

echo "[7/8] Timezone PHP"
if [[ -f /etc/zabbix/apache.conf ]]; then
  sed -i "s@# php_value date.timezone Europe/Riga@php_value date.timezone ${PHP_TZ}@" /etc/zabbix/apache.conf || true
  grep -q "php_value date.timezone" /etc/zabbix/apache.conf || echo "php_value date.timezone ${PHP_TZ}" >> /etc/zabbix/apache.conf
fi

echo "[8/8] Activation services et firewall"
systemctl enable zabbix-server zabbix-agent apache2 mariadb
systemctl restart zabbix-server zabbix-agent apache2 mariadb

ufw allow 80/tcp comment 'HTTP Zabbix'
ufw allow 443/tcp comment 'HTTPS Zabbix'
ufw allow 10051/tcp comment 'Zabbix Server'
ufw allow 10050/tcp comment 'Zabbix Agent'
ufw --force enable

echo
echo "OK: srv-zabbix prêt."
echo "Interface : http://192.168.1.11/zabbix"
echo "Compte par défaut Zabbix : Admin / zabbix"
echo "À faire dans l'interface : ajouter srv-web avec templates Linux by Zabbix agent, Apache by HTTP, MySQL by Zabbix agent, SSH service availability."
