#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   sudo ./00-common-debian12.sh srv-web 192.168.1.10
#   sudo ./00-common-debian12.sh srv-zabbix 192.168.1.11
#   sudo ./00-common-debian12.sh srv-grafana 192.168.1.12
#   sudo ./00-common-debian12.sh srv-observium 192.168.1.13
#
# Attention : ce script modifie l'adresse IP. À exécuter depuis la console de la VM.

if [[ $EUID -ne 0 ]]; then
  echo "ERREUR: lancer ce script en root ou avec sudo."
  exit 1
fi

HOSTNAME_NEW="${1:-}"
IPADDR="${2:-}"
PREFIX="${PREFIX:-24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
DNS1="${DNS1:-8.8.8.8}"
DNS2="${DNS2:-1.1.1.1}"

if [[ -z "$HOSTNAME_NEW" || -z "$IPADDR" ]]; then
  echo "Usage: sudo $0 <hostname> <ip>"
  exit 1
fi

detect_iface() {
  local iface=""
  iface="$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}' || true)"
  if [[ -z "$iface" ]]; then
    iface="$(ip -o link show | awk -F': ' '$2!="lo"{print $2; exit}')"
  fi
  echo "$iface"
}

IFACE="${IFACE:-$(detect_iface)}"
if [[ -z "$IFACE" ]]; then
  echo "ERREUR: impossible de détecter l'interface réseau."
  exit 1
fi

echo "[1/7] Configuration hostname : $HOSTNAME_NEW"
hostnamectl set-hostname "$HOSTNAME_NEW"
echo "$HOSTNAME_NEW" > /etc/hostname

echo "[2/7] Configuration /etc/hosts"
cp -a /etc/hosts "/etc/hosts.bak.$(date +%F-%H%M%S)" || true
cat >/etc/hosts <<'EOF'
127.0.0.1 localhost
192.168.1.10 srv-web
192.168.1.11 srv-zabbix
192.168.1.12 srv-grafana
192.168.1.13 srv-observium
192.168.1.50 cli-win

# IPv6 local
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
echo "$IPADDR $HOSTNAME_NEW" >> /etc/hosts

echo "[3/7] Configuration IP statique sur interface $IFACE"

if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
  CON_NAME="$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v dev="$IFACE" '$2==dev{print $1; exit}')"
  if [[ -z "$CON_NAME" ]]; then
    CON_NAME="lab-$IFACE"
    nmcli con add type ethernet ifname "$IFACE" con-name "$CON_NAME"
  fi
  nmcli con mod "$CON_NAME" ipv4.addresses "$IPADDR/$PREFIX"
  nmcli con mod "$CON_NAME" ipv4.gateway "$GATEWAY"
  nmcli con mod "$CON_NAME" ipv4.dns "$DNS1 $DNS2"
  nmcli con mod "$CON_NAME" ipv4.method manual
  nmcli con up "$CON_NAME" || true

elif systemctl list-unit-files | grep -q '^systemd-networkd.service'; then
  mkdir -p /etc/systemd/network
  cat >/etc/systemd/network/10-lab.network <<EOF
[Match]
Name=$IFACE

[Network]
Address=$IPADDR/$PREFIX
Gateway=$GATEWAY
DNS=$DNS1
DNS=$DNS2
EOF
  if [[ -d /etc/cloud/cloud.cfg.d ]]; then
    cat >/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<'EOF'
network: {config: disabled}
EOF
  fi
  systemctl enable systemd-networkd || true
  systemctl restart systemd-networkd || true

else
  mkdir -p /etc/network/interfaces.d
  sed -i.bak "/$IFACE/d" /etc/network/interfaces || true
  cat >/etc/network/interfaces.d/50-lab-static <<EOF
auto $IFACE
iface $IFACE inet static
    address $IPADDR/$PREFIX
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
EOF
  ifdown "$IFACE" 2>/dev/null || true
  ifup "$IFACE" 2>/dev/null || true
fi

echo "[4/7] Mise à jour système et outils de base"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  ca-certificates curl wget gnupg lsb-release apt-transport-https \
  sudo vim nano net-tools dnsutils iproute2 unzip tar \
  openssh-server ufw chrony qemu-guest-agent open-vm-tools

echo "[5/7] Activation des services utiles"
systemctl enable --now ssh || true
systemctl enable --now chrony || true
systemctl enable --now qemu-guest-agent || true
systemctl enable --now open-vm-tools || true

echo "[6/7] Fuseau horaire"
timedatectl set-timezone Europe/Paris || true

echo "[7/7] Pare-feu de base"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable

echo
echo "OK: base Debian configurée pour $HOSTNAME_NEW ($IPADDR/$PREFIX)."
echo "Conseil: redémarre la VM avant de lancer le script applicatif."
