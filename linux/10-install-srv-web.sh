#!/usr/bin/env bash
set -Eeuo pipefail

# VM cible : srv-web / 192.168.1.10
# Services : Apache, MariaDB, PHP, Zabbix Agent, SNMP, stress

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer en root ou sudo."
  exit 1
fi

ZABBIX_SERVER="${ZABBIX_SERVER:-192.168.1.11}"
HOSTNAME_EXPECTED="${HOSTNAME_EXPECTED:-srv-web}"
TEST_DB_PASS="${TEST_DB_PASS:-P@ssw0rd!}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/8] Pré-requis"
apt-get update
apt-get install -y ca-certificates curl wget gnupg lsb-release

echo "[2/8] Installation Apache/MariaDB/PHP"
apt-get install -y apache2 mariadb-server php php-mysql libapache2-mod-php php-cli \
  php-curl php-xml php-mbstring php-gd stress snmpd snmp ufw

echo "[3/8] Page PHP de test"
cat >/var/www/html/index.php <<'EOF'
<?php
echo "<h1>srv-web - TP Supervision</h1>";
echo "<p>Apache + PHP + MariaDB opérationnels.</p>";
phpinfo();
?>
EOF
chown www-data:www-data /var/www/html/index.php

echo "[4/8] Sécurisation minimale MariaDB et base de test"
systemctl enable --now mariadb

mysql <<SQL
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS testdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'testuser'@'localhost' IDENTIFIED BY '${TEST_DB_PASS}';
GRANT ALL PRIVILEGES ON testdb.* TO 'testuser'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "[5/8] Installation dépôt Zabbix 7.0 LTS + agent"
ZBX_DEB="/tmp/zabbix-release.deb"
if ! wget -q -O "$ZBX_DEB" "https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.0+debian12_all.deb"; then
  wget -q -O "$ZBX_DEB" "https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1+debian12_all.deb"
fi
dpkg -i "$ZBX_DEB"
apt-get update
apt-get install -y zabbix-agent

echo "[6/8] Configuration Zabbix Agent"
cp -a /etc/zabbix/zabbix_agentd.conf "/etc/zabbix/zabbix_agentd.conf.bak.$(date +%F-%H%M%S)"
sed -i "s/^Server=.*/Server=${ZABBIX_SERVER}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=.*/ServerActive=${ZABBIX_SERVER}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=.*/Hostname=${HOSTNAME_EXPECTED}/" /etc/zabbix/zabbix_agentd.conf
systemctl enable --now zabbix-agent
systemctl restart zabbix-agent

echo "[7/8] Configuration SNMP pour Observium"
cp -a /etc/snmp/snmpd.conf "/etc/snmp/snmpd.conf.bak.$(date +%F-%H%M%S)" || true
cat >/etc/snmp/snmpd.conf <<'EOF'
agentAddress udp:161
rocommunity public 192.168.1.0/24
sysLocation TP Supervision - LAN 192.168.1.0/24
sysContact admin@formation.lan
EOF
systemctl enable --now snmpd
systemctl restart snmpd

echo "[8/8] Apache status + firewall"
a2enmod status rewrite headers >/dev/null
cat >/etc/apache2/conf-available/server-status-zabbix.conf <<'EOF'
<Location "/server-status">
    SetHandler server-status
    Require ip 127.0.0.1
    Require ip 192.168.1.11
</Location>
ExtendedStatus On
EOF
a2enconf server-status-zabbix >/dev/null
apache2ctl configtest
systemctl enable --now apache2
systemctl reload apache2

ufw allow 80/tcp comment 'HTTP Apache'
ufw allow 443/tcp comment 'HTTPS Apache'
ufw allow 10050/tcp comment 'Zabbix Agent'
ufw allow from 192.168.1.0/24 to any port 161 proto udp comment 'SNMP LAN'
ufw --force enable

echo
echo "OK: srv-web prêt."
echo "Tests :"
echo "  curl http://192.168.1.10"
echo "  zabbix_get -s 192.168.1.10 -k agent.ping depuis srv-zabbix"
echo "  snmpwalk -v2c -c public 192.168.1.10 sysName depuis srv-observium"
