#!/usr/bin/env bash
# Correctif web Observium pour srv-observium / Debian 12
# Objectif : rendre l'interface accessible sur http://192.168.1.13/ et http://192.168.1.13/observium
# By Shadowhacker (sbeteta)
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer avec sudo ou en root."
  exit 1
fi

OBS_DB_PASS="${OBS_DB_PASS:-Observium1!}"
OBS_ADMIN_PASS="${OBS_ADMIN_PASS:-Observium1!}"
OBS_DIR="/opt/observium"
OBS_HTML="/opt/observium/html"

export DEBIAN_FRONTEND=noninteractive

echo "[1/8] Vérification réseau local"
ip -br a || true
ip route || true

echo "[2/8] Installation/complément des paquets Apache/PHP"
apt-get update
apt-get install -y \
  apache2 mariadb-server \
  php php-cli libapache2-mod-php php-mysql php-gd php-json php-mbstring php-snmp php-xml php-curl php-zip php-bcmath php-gmp php-intl \
  snmp snmpd fping rrdtool graphviz imagemagick whois mtr-tiny nmap ipmitool \
  python3-pymysql python3-dotenv curl wget unzip tar ufw

if [[ ! -d "${OBS_DIR}" ]]; then
  echo "[3/8] Observium absent : téléchargement"
  mkdir -p /opt
  wget -O /tmp/observium-community-latest.tar.gz http://www.observium.org/observium-community-latest.tar.gz
  tar zxvf /tmp/observium-community-latest.tar.gz -C /opt
else
  echo "[3/8] Observium déjà présent dans ${OBS_DIR}"
fi

cd "${OBS_DIR}"

echo "[4/8] Base MariaDB Observium"
systemctl enable --now mariadb
mysql <<SQL
CREATE DATABASE IF NOT EXISTS observium DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'observium'@'localhost' IDENTIFIED BY '${OBS_DB_PASS}';
ALTER USER 'observium'@'localhost' IDENTIFIED BY '${OBS_DB_PASS}';
GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'localhost';
FLUSH PRIVILEGES;
SQL

if [[ ! -f "${OBS_DIR}/config.php" ]]; then
  cp "${OBS_DIR}/config.php.default" "${OBS_DIR}/config.php"
fi

# Mise à jour robuste du config.php
sed -i "s/^\$config\['db_user'\].*/\$config['db_user'] = 'observium';/" "${OBS_DIR}/config.php" || true
sed -i "s/^\$config\['db_pass'\].*/\$config['db_pass'] = '${OBS_DB_PASS}';/" "${OBS_DIR}/config.php" || true
sed -i "s/^\$config\['db_name'\].*/\$config['db_name'] = 'observium';/" "${OBS_DIR}/config.php" || true

grep -q "\$config\['fping'\]" "${OBS_DIR}/config.php" || cat >>"${OBS_DIR}/config.php" <<'PHP'

// Chemins Debian
$config['fping'] = "/usr/bin/fping";
$config['fping6'] = "/usr/bin/fping6";
PHP

echo "[5/8] Initialisation/upgrade schéma Observium"
php "${OBS_DIR}/discovery.php" -u || true

echo "[6/8] Permissions Observium"
mkdir -p "${OBS_DIR}/logs" "${OBS_DIR}/rrd"
chown -R www-data:www-data "${OBS_DIR}/logs" "${OBS_DIR}/rrd" "${OBS_HTML}"
find "${OBS_DIR}/logs" "${OBS_DIR}/rrd" -type d -exec chmod 775 {} \; || true

if [[ -x "${OBS_DIR}/adduser.php" ]]; then
  php "${OBS_DIR}/adduser.php" admin "${OBS_ADMIN_PASS}" 10 || true
fi

echo "[7/8] Correction VirtualHost Apache"
cat >/etc/apache2/sites-available/observium.conf <<'APACHE'
<VirtualHost *:80>
    ServerName srv-observium
    ServerAdmin admin@formation.lan

    # Accès direct recommandé : http://192.168.1.13/
    DocumentRoot /opt/observium/html
    DirectoryIndex index.php index.html

    # Compatibilité TP : http://192.168.1.13/observium
    Alias /observium /opt/observium/html

    <Directory /opt/observium/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/observium_error.log
    CustomLog ${APACHE_LOG_DIR}/observium_access.log combined
</VirtualHost>
APACHE

PHP_VER="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
a2enmod rewrite >/dev/null
if [[ -n "${PHP_VER}" && -e "/etc/apache2/mods-available/php${PHP_VER}.load" ]]; then
  a2enmod "php${PHP_VER}" >/dev/null || true
fi

a2dissite 000-default >/dev/null 2>&1 || true
a2ensite observium >/dev/null
apache2ctl configtest
systemctl enable --now apache2
systemctl restart apache2

echo "[8/8] Pare-feu et tests locaux"
ufw allow 22/tcp comment 'SSH admin' || true
ufw allow 80/tcp comment 'HTTP Observium' || true
ufw allow 443/tcp comment 'HTTPS Observium' || true
ufw --force enable || true

systemctl --no-pager --full status apache2 || true
ss -lntp | grep ':80' || true

echo
curl -I http://127.0.0.1/ || true
echo
curl -I http://127.0.0.1/observium/ || true

echo
hostname -I || true
echo "Correctif terminé. Tester depuis le navigateur :"
echo "  http://192.168.1.13/"
echo "  http://192.168.1.13/observium/"
echo "Compte Observium : admin / ${OBS_ADMIN_PASS}"
