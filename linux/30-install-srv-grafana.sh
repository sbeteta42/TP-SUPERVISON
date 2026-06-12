#!/usr/bin/env bash
# By Shadowhacker (sbeteta)
set -Eeuo pipefail

# VM cible : srv-grafana / 192.168.1.12
# Services : Grafana + plugin Zabbix + datasource provisionnée

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer en root ou sudo."
  exit 1
fi

ZABBIX_API_URL="${ZABBIX_API_URL:-http://192.168.1.11/zabbix/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASS="${ZABBIX_PASS:-zabbix}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Pré-requis"
apt-get update
apt-get install -y apt-transport-https wget gnupg ca-certificates curl software-properties-common ufw

echo "[2/6] Dépôt Grafana officiel"
mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

apt-get update

echo "[3/6] Installation Grafana OSS"
apt-get install -y grafana

echo "[4/6] Plugin Zabbix pour Grafana"
grafana-cli plugins install alexanderzobnin-zabbix-app || true

# Certaines versions du plugin nécessitent l'autorisation du datasource unsigned.
if ! grep -q "^allow_loading_unsigned_plugins" /etc/grafana/grafana.ini; then
  sed -i '/^\[plugins\]/a allow_loading_unsigned_plugins = alexanderzobnin-zabbix-datasource' /etc/grafana/grafana.ini
else
  sed -i 's/^allow_loading_unsigned_plugins.*/allow_loading_unsigned_plugins = alexanderzobnin-zabbix-datasource/' /etc/grafana/grafana.ini
fi

echo "[5/6] Provisioning datasource Zabbix"
mkdir -p /etc/grafana/provisioning/datasources
cat >/etc/grafana/provisioning/datasources/zabbix.yaml <<EOF
apiVersion: 1

datasources:
  - name: Zabbix
    type: alexanderzobnin-zabbix-datasource
    access: proxy
    url: ${ZABBIX_API_URL}
    isDefault: true
    jsonData:
      authType: userLogin
      username: ${ZABBIX_USER}
      trends: true
      trendsFrom: '7d'
      trendsRange: '4d'
      cacheTTL: '1h'
    secureJsonData:
      password: ${ZABBIX_PASS}
EOF

echo "[6/6] Activation service + tentative activation plugin via API"
systemctl enable --now grafana-server
sleep 8

# Activation de l'application Zabbix si l'API répond déjà.
curl -sS -u admin:admin \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"enabled":true,"pinned":true}' \
  http://127.0.0.1:3000/api/plugins/alexanderzobnin-zabbix-app/settings >/dev/null || true

systemctl restart grafana-server

ufw allow 3000/tcp comment 'Grafana'
ufw --force enable

echo
echo "OK: srv-grafana prêt."
echo "Interface : http://192.168.1.12:3000"
echo "Compte par défaut Grafana : admin / admin"
echo "Datasource Zabbix préconfigurée vers : ${ZABBIX_API_URL}"
echo "Si la datasource n'apparaît pas : Administration > Plugins and data > Plugins > Zabbix > Enable."
