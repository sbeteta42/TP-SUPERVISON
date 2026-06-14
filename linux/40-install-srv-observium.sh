#!/usr/bin/env bash
# By Shadowhacker (sbeteta)
# Version corrigée et robuste - Debian 12 / Observium Community
# VM cible : srv-observium / 192.168.1.13
# URL TP : http://192.168.1.13/observium/

set -Eeuo pipefail

trap 'echo "ERREUR ligne $LINENO : commande échouée -> $BASH_COMMAND" >&2' ERR

if [[ ${EUID} -ne 0 ]]; then
  echo "ERREUR: lancer ce script avec sudo ou en root."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# -----------------------------
# Variables pédagogiques
# -----------------------------
OBS_DB_NAME="${OBS_DB_NAME:-observium}"
OBS_DB_USER="${OBS_DB_USER:-observium}"
OBS_DB_PASS="${OBS_DB_PASS:-Observium1!}"
OBS_ADMIN_USER="${OBS_ADMIN_USER:-admin}"
OBS_ADMIN_PASS="${OBS_ADMIN_PASS:-Observium1!}"
OBS_DEVICE="${OBS_DEVICE:-srv-web}"
OBS_DEVICE_IP="${OBS_DEVICE_IP:-192.168.1.10}"
OBS_COMMUNITY="${OBS_COMMUNITY:-public}"
OBS_SERVER_IP="${OBS_SERVER_IP:-192.168.1.13}"
OBS_TARBALL_URL_HTTPS="${OBS_TARBALL_URL_HTTPS:-https://www.observium.org/observium-community-latest.tar.gz}"
OBS_TARBALL_URL_HTTP="${OBS_TARBALL_URL_HTTP:-http://www.observium.org/observium-community-latest.tar.gz}"
OBS_DIR="${OBS_DIR:-/opt/observium}"

log() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

apt_install() {
  apt-get install -y "$@"
}

ensure_hosts() {
  log "[1/12] Préparation hostname et /etc/hosts"

  hostnamectl set-hostname srv-observium || true

  grep -qE "^[[:space:]]*192\.168\.1\.10[[:space:]]+srv-web" /etc/hosts || echo "192.168.1.10 srv-web" >> /etc/hosts
  grep -qE "^[[:space:]]*192\.168\.1\.11[[:space:]]+srv-zabbix" /etc/hosts || echo "192.168.1.11 srv-zabbix" >> /etc/hosts
  grep -qE "^[[:space:]]*192\.168\.1\.12[[:space:]]+srv-grafana" /etc/hosts || echo "192.168.1.12 srv-grafana" >> /etc/hosts
  grep -qE "^[[:space:]]*192\.168\.1\.13[[:space:]]+srv-observium" /etc/hosts || echo "192.168.1.13 srv-observium" >> /etc/hosts
}

install_dependencies() {
  log "[2/12] Installation des dépendances Debian 12 / PHP 8.2 / Apache / MariaDB / SNMP"

  apt-get update
  apt_install ca-certificates curl wget gnupg lsb-release apt-transport-https software-properties-common

  # Paquets alignés sur Debian 12 : PHP 8.2 explicite pour éviter les surprises.
  apt_install \
    apache2 mariadb-server mariadb-client \
    libapache2-mod-php8.2 php8.2-cli php8.2-mysql php8.2-gd php8.2-bcmath php8.2-mbstring \
    php8.2-opcache php8.2-curl php8.2-xml php8.2-zip php8.2-snmp php8.2-apcu php-pear \
    snmp snmpd fping rrdtool graphviz imagemagick whois mtr-tiny nmap ipmitool \
    python3-mysqldb python3-pymysql python-is-python3 subversion unzip tar ufw
}

configure_php() {
  log "[3/12] Réglages PHP pour Observium"

  local php_ini_apache="/etc/php/8.2/apache2/php.ini"
  local php_ini_cli="/etc/php/8.2/cli/php.ini"

  for ini in "$php_ini_apache" "$php_ini_cli"; do
    if [[ -f "$ini" ]]; then
      sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$ini"
      sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$ini"
      sed -i 's/^;date.timezone =.*/date.timezone = Europe\/Paris/' "$ini"
      sed -i 's/^date.timezone =.*/date.timezone = Europe\/Paris/' "$ini"
    fi
  done
}

configure_mariadb() {
  log "[4/12] Configuration MariaDB pour Observium"

  cat >/etc/mysql/mariadb.conf.d/99-observium.cnf <<'EOF_MARIADB'
[mysqld]
innodb_file_per_table=1
sql_mode=""
EOF_MARIADB

  systemctl enable --now mariadb
  systemctl restart mariadb

  mysql <<SQL
CREATE DATABASE IF NOT EXISTS ${OBS_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER IF NOT EXISTS '${OBS_DB_USER}'@'localhost' IDENTIFIED BY '${OBS_DB_PASS}';
GRANT ALL PRIVILEGES ON ${OBS_DB_NAME}.* TO '${OBS_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
}

download_observium() {
  log "[5/12] Téléchargement et installation Observium Community"

  mkdir -p /opt
  cd /opt

  if [[ ! -d "$OBS_DIR" ]]; then
    rm -f /tmp/observium-community-latest.tar.gz
    if ! curl -fL --connect-timeout 20 --retry 3 -o /tmp/observium-community-latest.tar.gz "$OBS_TARBALL_URL_HTTPS"; then
      echo "HTTPS indisponible, tentative en HTTP..."
      curl -fL --connect-timeout 20 --retry 3 -o /tmp/observium-community-latest.tar.gz "$OBS_TARBALL_URL_HTTP"
    fi
    tar zxf /tmp/observium-community-latest.tar.gz -C /opt
  else
    echo "Observium existe déjà dans $OBS_DIR : conservation de l'installation existante."
  fi

  if [[ ! -d "$OBS_DIR/html" ]]; then
    echo "ERREUR: $OBS_DIR/html introuvable. Téléchargement Observium incorrect."
    exit 1
  fi
}

configure_observium() {
  log "[6/12] Configuration Observium config.php"

  cd "$OBS_DIR"

  if [[ ! -f config.php ]]; then
    cp config.php.default config.php
  fi

  # Remplacement robuste même si les lignes sont commentées ou espacées différemment.
  sed -i "s/^\s*\$config\['db_host'\].*/\$config['db_host'] = 'localhost';/" config.php || true
  sed -i "s/^\s*\$config\['db_user'\].*/\$config['db_user'] = '${OBS_DB_USER}';/" config.php || true
  sed -i "s/^\s*\$config\['db_pass'\].*/\$config['db_pass'] = '${OBS_DB_PASS}';/" config.php || true
  sed -i "s/^\s*\$config\['db_name'\].*/\$config['db_name'] = '${OBS_DB_NAME}';/" config.php || true

  grep -q "\$config\['db_user'\] = '${OBS_DB_USER}'" config.php || cat >>config.php <<EOF_CONFIG

// Configuration ajoutée automatiquement pour le TP supervision
\$config['db_host'] = 'localhost';
\$config['db_user'] = '${OBS_DB_USER}';
\$config['db_pass'] = '${OBS_DB_PASS}';
\$config['db_name'] = '${OBS_DB_NAME}';
EOF_CONFIG

  grep -q "\$config\['fping'\]" config.php || cat >>config.php <<'EOF_CONFIG2'

// Chemins Debian 12
$config['fping']  = "/usr/bin/fping";
$config['fping6'] = "/usr/bin/fping6";
EOF_CONFIG2

  mkdir -p "$OBS_DIR/logs" "$OBS_DIR/rrd"
  chown -R www-data:www-data "$OBS_DIR/logs" "$OBS_DIR/rrd" "$OBS_DIR/html"
  chmod 775 "$OBS_DIR/logs" "$OBS_DIR/rrd"
}

initialize_observium_db() {
  log "[7/12] Initialisation du schéma Observium"

  cd "$OBS_DIR"

  # Observium indique que quelques erreurs de révision SQL peuvent être normales.
  php ./discovery.php -u || true

  if [[ -x ./adduser.php || -f ./adduser.php ]]; then
    php ./adduser.php "${OBS_ADMIN_USER}" "${OBS_ADMIN_PASS}" 10 || true
  fi
}

configure_apache() {
  log "[8/12] Configuration Apache fiable : / et /observium/"

  a2enmod rewrite >/dev/null
  a2enmod php8.2 >/dev/null 2>&1 || true

  cat >/etc/apache2/sites-available/observium.conf <<EOF_APACHE
<VirtualHost *:80>
    ServerName srv-observium
    ServerAdmin admin@formation.lan

    DocumentRoot ${OBS_DIR}/html
    DirectoryIndex index.php index.html

    # Accès attendu dans le TP : http://${OBS_SERVER_IP}/observium/
    Alias /observium ${OBS_DIR}/html

    <Directory ${OBS_DIR}/html>
        Options FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    ErrorLog ${OBS_DIR}/logs/apache_error.log
    CustomLog ${OBS_DIR}/logs/apache_access.log combined
</VirtualHost>
EOF_APACHE

  a2dissite 000-default >/dev/null 2>&1 || true
  a2ensite observium >/dev/null

  apache2ctl configtest
  systemctl enable --now apache2
  systemctl restart apache2
}

configure_snmp_local() {
  log "[9/12] Configuration SNMP locale minimale"

  cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true

  cat >/etc/snmp/snmpd.conf <<EOF_SNMP
agentAddress udp:161,udp6:[::1]:161
rocommunity ${OBS_COMMUNITY} 127.0.0.1
rocommunity ${OBS_COMMUNITY} 192.168.1.0/24
sysLocation TP-Supervision
sysContact admin@formation.lan
EOF_SNMP

  systemctl enable --now snmpd
  systemctl restart snmpd
}

configure_cron() {
  log "[10/12] Configuration cron Observium"

  cat >/etc/cron.d/observium <<EOF_CRON
# Observium poller/discovery - TP supervision
*/5 * * * * root ${OBS_DIR}/poller-wrapper.py 4 >> /dev/null 2>&1
33 */6 * * * root ${OBS_DIR}/discovery.php -h all >> /dev/null 2>&1
13 5 * * * root ${OBS_DIR}/discovery.php -h new >> /dev/null 2>&1
EOF_CRON

  chmod 644 /etc/cron.d/observium
  systemctl enable --now cron
}

configure_firewall() {
  log "[11/12] Configuration UFW sans couper SSH"

  ufw allow 22/tcp comment 'SSH admin cloud-init'
  ufw allow 80/tcp comment 'HTTP Observium'
  ufw allow 443/tcp comment 'HTTPS Observium futur'
  ufw allow from 192.168.1.0/24 to any port 161 proto udp comment 'SNMP LAN'
  ufw --force enable
}

add_initial_device_if_possible() {
  log "[12/12] Ajout optionnel du device ${OBS_DEVICE} si SNMP répond"

  cd "$OBS_DIR"

  if ! grep -qE "^[[:space:]]*${OBS_DEVICE_IP}[[:space:]]+${OBS_DEVICE}" /etc/hosts; then
    echo "${OBS_DEVICE_IP} ${OBS_DEVICE}" >> /etc/hosts
  fi

  if ping -c 1 -W 2 "${OBS_DEVICE}" >/dev/null 2>&1; then
    if snmpwalk -v2c -c "${OBS_COMMUNITY}" "${OBS_DEVICE}" sysName.0 >/dev/null 2>&1; then
      php ./add_device.php "${OBS_DEVICE}" "${OBS_COMMUNITY}" v2c || true
      php ./discovery.php -h all || true
      php ./poller.php -h all || true
    else
      echo "INFO: ${OBS_DEVICE} répond au ping mais pas encore en SNMP v2c community '${OBS_COMMUNITY}'."
      echo "      À faire sur srv-web : configurer /etc/snmp/snmpd.conf avec rocommunity ${OBS_COMMUNITY}."
      echo "      Puis relancer : sudo php ${OBS_DIR}/add_device.php ${OBS_DEVICE} ${OBS_COMMUNITY} v2c"
    fi
  else
    echo "INFO: ${OBS_DEVICE} non joignable pour le moment. Ce n'est pas bloquant pour l'interface web Observium."
  fi
}

final_tests() {
  log "Tests finaux"

  echo "Etat réseau :"
  ip -br addr || true
  echo

  echo "Etat des services :"
  systemctl is-active --quiet apache2 && echo "apache2 : actif" || echo "apache2 : ERREUR"
  systemctl is-active --quiet mariadb && echo "mariadb : actif" || echo "mariadb : ERREUR"
  systemctl is-active --quiet snmpd && echo "snmpd   : actif" || echo "snmpd   : ERREUR"
  echo

  local code_root code_obs
  code_root="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ || true)"
  code_obs="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/observium/ || true)"

  echo "HTTP local /           : ${code_root}"
  echo "HTTP local /observium/ : ${code_obs}"

  if [[ ! "$code_root" =~ ^(200|301|302|303)$ ]] && [[ ! "$code_obs" =~ ^(200|301|302|303)$ ]]; then
    echo
    echo "ERREUR: Apache ne semble pas servir Observium correctement. Logs utiles :"
    echo "  sudo tail -n 80 ${OBS_DIR}/logs/apache_error.log"
    echo "  sudo tail -n 80 /var/log/apache2/error.log"
    exit 1
  fi

  echo
  echo "OK: srv-observium est prêt."
  echo "Interface principale : http://${OBS_SERVER_IP}/"
  echo "Interface TP         : http://${OBS_SERVER_IP}/observium/"
  echo "Compte Observium     : ${OBS_ADMIN_USER} / ${OBS_ADMIN_PASS}"
  echo
  echo "Diagnostic utile en cas de souci :"
  echo "  sudo apache2ctl -S"
  echo "  sudo tail -n 80 ${OBS_DIR}/logs/apache_error.log"
  echo "  sudo systemctl status apache2 mariadb snmpd --no-pager"
}

main() {
  ensure_hosts
  install_dependencies
  configure_php
  configure_mariadb
  download_observium
  configure_observium
  initialize_observium_db
  configure_apache
  configure_snmp_local
  configure_cron
  configure_firewall
  add_initial_device_if_possible
  final_tests
}

main "$@"
