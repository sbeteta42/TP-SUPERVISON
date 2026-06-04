#!/usr/bin/env bash
set -Eeuo pipefail

# Script de préparation QEMU/KVM/libvirt pour le TP Supervision.
# Version avec pfSense qcow2 démarré en premier, puis VMs Debian 12.
#
# Topologie TP :
#   pfSense LAN : 192.168.1.1/24
#   srv-web     : 192.168.1.10/24
#   srv-zabbix  : 192.168.1.11/24
#   srv-grafana : 192.168.1.12/24
#   srv-observium : 192.168.1.13/24
#
# Identifiants pfSense fournis pour le labo :
#   login : admin
#   mot de passe : pfsense
#
# Pré-requis Debian/Ubuntu host :
#   sudo apt update
#   sudo apt install -y qemu-kvm libvirt-daemon-system virtinst virt-manager \
#     cloud-image-utils qemu-utils wget curl openssl megatools
#
# IMPORTANT MEGA :
#   wget ne sait pas télécharger directement une URL Mega chiffrée.
#   Le script utilise megadl si disponible.
#   Sinon, téléchargez manuellement le qcow2 pfSense et placez-le ici :
#     ${STORAGE_DIR}/pfsense-lab-base.qcow2

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~${REAL_USER}")"

STORAGE_DIR="${STORAGE_DIR:-${REAL_HOME}/tp-supervision}"

LAN_NET_NAME="${LAN_NET_NAME:-TP-SUPERV-LAN}"
WAN_NET_NAME="${WAN_NET_NAME:-TP-SUPERV-WAN}"
LAN_BRIDGE_BASE="${LAN_BRIDGE_BASE:-virbr-superv}"
WAN_BRIDGE_BASE="${WAN_BRIDGE_BASE:-virbr-pfswan}"
LAN_BRIDGE_NAME="$LAN_BRIDGE_BASE"
WAN_BRIDGE_NAME="$WAN_BRIDGE_BASE"

DEBIAN_IMG_URL="${DEBIAN_IMG_URL:-https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2}"
DEBIAN_BASE="${STORAGE_DIR}/debian-12-genericcloud-amd64.qcow2"

PFSENSE_VM_NAME="${PFSENSE_VM_NAME:-pfsense}"
PFSENSE_IMG_URL="${PFSENSE_IMG_URL:-https://mega.nz/file/e5gXBCab#aOzIvHFlqrUZJOhEdVduQD4arSF-sWtMwFYygD4w4kA}"
PFSENSE_BASE="${PFSENSE_BASE:-${STORAGE_DIR}/pfsense-lab-base.qcow2}"
PFSENSE_DISK="${PFSENSE_DISK:-${STORAGE_DIR}/${PFSENSE_VM_NAME}.qcow2}"
PFSENSE_RAM="${PFSENSE_RAM:-1024}"
PFSENSE_VCPUS="${PFSENSE_VCPUS:-1}"
PFSENSE_BOOT_WAIT="${PFSENSE_BOOT_WAIT:-45}"
PFSENSE_OS_VARIANT="${PFSENSE_OS_VARIANT:-freebsd13.0}"

VM_USER="${VM_USER:-admin}"
VM_PASS="${VM_PASS:-P@ssw0rd}"

# Si l'image pfSense fournie a déjà ses interfaces configurées :
#   vtnet0 = WAN en DHCP sur réseau NAT libvirt
#   vtnet1 = LAN en 192.168.1.1/24
# l'ordre ci-dessous doit rester WAN puis LAN.
PFSENSE_WAN_MODEL="${PFSENSE_WAN_MODEL:-virtio}"
PFSENSE_LAN_MODEL="${PFSENSE_LAN_MODEL:-virtio}"

# Si l'image pfSense ne voit pas correctement les interfaces virtio,
# relancer avec :
#   sudo PFSENSE_WAN_MODEL=e1000 PFSENSE_LAN_MODEL=e1000 ./create-vms-libvirt-with-pfsense.sh

# Adresses IP fixes des VMs Debian.
declare -A IPS=(
  [srv-web]="192.168.1.10"
  [srv-zabbix]="192.168.1.11"
  [srv-grafana]="192.168.1.12"
  [srv-observium]="192.168.1.13"
)

declare -A RAMS=(
  [srv-web]="512"
  [srv-zabbix]="2048"
  [srv-grafana]="1024"
  [srv-observium]="1024"
)

declare -A VCPUS=(
  [srv-web]="1"
  [srv-zabbix]="2"
  [srv-grafana]="1"
  [srv-observium]="1"
)

log() {
  echo -e "\n[TP-SUPERVISION] $*"
}

warn() {
  echo -e "\n[ATTENTION] $*" >&2
}

fail() {
  echo -e "\n[ERREUR] $*" >&2
  exit 1
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    fail "Lancer le script avec sudo."
  fi
}

require_cmds() {
  local missing=()
  for cmd in virsh virt-install qemu-img cloud-localds wget openssl ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    fail "Commandes manquantes : ${missing[*]}\nInstaller les prérequis : sudo apt install -y qemu-kvm libvirt-daemon-system virtinst virt-manager cloud-image-utils qemu-utils wget curl openssl megatools"
  fi
}

ensure_storage() {
  mkdir -p "$STORAGE_DIR"
  chown -R "$REAL_USER":"$REAL_USER" "$STORAGE_DIR" || true
}

resolve_bridge_name() {
  local base="$1"
  local candidate="$base"
  local i=1

  while ip link show "$candidate" >/dev/null 2>&1; do
    candidate="${base}${i}"
    i=$((i + 1))
    if (( i > 9 )); then
      fail "Impossible de trouver un nom de bridge libre à partir de ${base}."
    fi
  done

  echo "$candidate"
}

ensure_net_started() {
  local net_name="$1"

  if ! virsh net-info "$net_name" >/dev/null 2>&1; then
    fail "Le réseau libvirt ${net_name} n'existe pas."
  fi

  if ! virsh net-info "$net_name" | grep -q "Active:.*yes"; then
    virsh net-start "$net_name"
  fi

  virsh net-autostart "$net_name" >/dev/null
}

create_lan_network() {
  if virsh net-info "$LAN_NET_NAME" >/dev/null 2>&1; then
    log "Réseau LAN libvirt ${LAN_NET_NAME} déjà présent."
    ensure_net_started "$LAN_NET_NAME"
    return
  fi

  LAN_BRIDGE_NAME="$(resolve_bridge_name "$LAN_BRIDGE_BASE")"

  cat >"/tmp/${LAN_NET_NAME}.xml" <<EOF_NET
<network>
  <name>${LAN_NET_NAME}</name>
  <bridge name='${LAN_BRIDGE_NAME}' stp='on' delay='0'/>
  <ip address='192.168.1.254' netmask='255.255.255.0'>
  </ip>
</network>
EOF_NET

  log "Création du réseau LAN ${LAN_NET_NAME} sur bridge ${LAN_BRIDGE_NAME}."
  virsh net-define "/tmp/${LAN_NET_NAME}.xml"
  virsh net-start "$LAN_NET_NAME"
  virsh net-autostart "$LAN_NET_NAME" >/dev/null
}

create_wan_network() {
  if virsh net-info "$WAN_NET_NAME" >/dev/null 2>&1; then
    log "Réseau WAN/NAT libvirt ${WAN_NET_NAME} déjà présent."
    ensure_net_started "$WAN_NET_NAME"
    return
  fi

  WAN_BRIDGE_NAME="$(resolve_bridge_name "$WAN_BRIDGE_BASE")"

  cat >"/tmp/${WAN_NET_NAME}.xml" <<EOF_NET
<network>
  <name>${WAN_NET_NAME}</name>
  <forward mode='nat'/>
  <bridge name='${WAN_BRIDGE_NAME}' stp='on' delay='0'/>
  <ip address='10.99.0.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.99.0.100' end='10.99.0.200'/>
    </dhcp>
  </ip>
</network>
EOF_NET

  log "Création du réseau WAN/NAT ${WAN_NET_NAME} sur bridge ${WAN_BRIDGE_NAME}."
  virsh net-define "/tmp/${WAN_NET_NAME}.xml"
  virsh net-start "$WAN_NET_NAME"
  virsh net-autostart "$WAN_NET_NAME" >/dev/null
}

download_pfsense_image() {
  if [[ -f "$PFSENSE_BASE" ]]; then
    log "Image pfSense déjà présente : ${PFSENSE_BASE}"
    return
  fi

  log "Téléchargement de l'image pfSense qcow2 depuis Mega."

  if command -v megadl >/dev/null 2>&1; then
    local before_file after_file downloaded
    before_file="$(mktemp)"
    after_file="$(mktemp)"

    find "$STORAGE_DIR" -maxdepth 1 -type f | sort > "$before_file"
    megadl --path "$STORAGE_DIR" "$PFSENSE_IMG_URL"
    find "$STORAGE_DIR" -maxdepth 1 -type f | sort > "$after_file"

    downloaded="$(comm -13 "$before_file" "$after_file" | grep -Ei '\.(qcow2|img|raw)$' | head -n 1 || true)"
    rm -f "$before_file" "$after_file"

    if [[ -z "$downloaded" ]]; then
      downloaded="$(find "$STORAGE_DIR" -maxdepth 1 -type f -iname '*pfsense*' | head -n 1 || true)"
    fi

    if [[ -z "$downloaded" || ! -f "$downloaded" ]]; then
      fail "Téléchargement Mega terminé, mais aucun fichier qcow2/img/raw détecté dans ${STORAGE_DIR}. Renommer le fichier téléchargé en ${PFSENSE_BASE}."
    fi

    mv "$downloaded" "$PFSENSE_BASE"
    chown "$REAL_USER":"$REAL_USER" "$PFSENSE_BASE" || true
    log "Image pfSense stockée : ${PFSENSE_BASE}"
    return
  fi

  if command -v mega-get >/dev/null 2>&1; then
    mega-get "$PFSENSE_IMG_URL" "$PFSENSE_BASE"
    chown "$REAL_USER":"$REAL_USER" "$PFSENSE_BASE" || true
    log "Image pfSense stockée : ${PFSENSE_BASE}"
    return
  fi

  fail "Aucun outil Mega trouvé. Installer megatools : sudo apt install -y megatools\nOu télécharger manuellement l'image qcow2 et la placer ici : ${PFSENSE_BASE}"
}

create_pfsense_vm() {
  download_pfsense_image

  if virsh dominfo "$PFSENSE_VM_NAME" >/dev/null 2>&1; then
    log "VM ${PFSENSE_VM_NAME} déjà présente."
    start_vm_if_needed "$PFSENSE_VM_NAME"
    return
  fi

  if [[ ! -f "$PFSENSE_DISK" ]]; then
    log "Création du disque overlay pfSense : ${PFSENSE_DISK}"
    qemu-img create -f qcow2 -F qcow2 -b "$PFSENSE_BASE" "$PFSENSE_DISK"
    chown "$REAL_USER":"$REAL_USER" "$PFSENSE_DISK" || true
  fi

  log "Création de la VM pfSense. Ordre des cartes : WAN puis LAN."
  virt-install \
    --name "$PFSENSE_VM_NAME" \
    --memory "$PFSENSE_RAM" \
    --vcpus "$PFSENSE_VCPUS" \
    --disk path="$PFSENSE_DISK",format=qcow2,bus=virtio \
    --os-variant "$PFSENSE_OS_VARIANT" \
    --import \
    --network network="$WAN_NET_NAME",model="$PFSENSE_WAN_MODEL" \
    --network network="$LAN_NET_NAME",model="$PFSENSE_LAN_MODEL" \
    --graphics spice,listen=127.0.0.1 \
    --noautoconsole

  start_vm_if_needed "$PFSENSE_VM_NAME"
}

start_vm_if_needed() {
  local name="$1"
  local state
  state="$(virsh domstate "$name" 2>/dev/null || true)"

  if [[ "$state" != "running" ]]; then
    log "Démarrage de ${name}."
    virsh start "$name"
  else
    log "${name} est déjà démarrée."
  fi
}

wait_for_pfsense() {
  log "Pause de ${PFSENSE_BOOT_WAIT}s pour laisser pfSense démarrer avant les VMs Debian."
  sleep "$PFSENSE_BOOT_WAIT"
}

download_debian_base() {
  mkdir -p "$STORAGE_DIR"
  if [[ ! -f "$DEBIAN_BASE" ]]; then
    log "Téléchargement Debian 12 cloud image."
    wget -O "$DEBIAN_BASE" "$DEBIAN_IMG_URL"
    chown "$REAL_USER":"$REAL_USER" "$DEBIAN_BASE" || true
  else
    log "Image Debian déjà présente : ${DEBIAN_BASE}"
  fi
}

create_debian_vm() {
  local name="$1"
  local ip="${IPS[$name]}"
  local ram="${RAMS[$name]}"
  local vcpus="${VCPUS[$name]}"
  local disk="${STORAGE_DIR}/${name}.qcow2"
  local seed="${STORAGE_DIR}/${name}-seed.iso"

  if virsh dominfo "$name" >/dev/null 2>&1; then
    log "VM ${name} déjà présente, ignorée."
    start_vm_if_needed "$name"
    return
  fi

  log "Création de ${name} en ${ip}/24."
  qemu-img create -f qcow2 -F qcow2 -b "$DEBIAN_BASE" "$disk" 30G
  chown "$REAL_USER":"$REAL_USER" "$disk" || true

  local pass_hash
  pass_hash="$(openssl passwd -6 "$VM_PASS")"

  rm -rf "/tmp/cloudinit-${name}"
  mkdir -p "/tmp/cloudinit-${name}"

  cat >"/tmp/cloudinit-${name}/user-data" <<EOF_CLOUD
#cloud-config
hostname: ${name}
fqdn: ${name}.formation.lan
manage_etc_hosts: true
users:
  - name: ${VM_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${pass_hash}
ssh_pwauth: true
disable_root: false
package_update: true
packages:
  - sudo
  - openssh-server
  - qemu-guest-agent
  - curl
  - wget
  - vim
  - nano
  - net-tools
  - dnsutils
  - iputils-ping
  - ca-certificates
  - gnupg
timezone: Europe/Paris
write_files:
  - path: /etc/hosts
    append: true
    content: |
      192.168.1.1 pfsense pfsense.formation.lan
      192.168.1.10 srv-web srv-web.formation.lan
      192.168.1.11 srv-zabbix srv-zabbix.formation.lan
      192.168.1.12 srv-grafana srv-grafana.formation.lan
      192.168.1.13 srv-observium srv-observium.formation.lan
runcmd:
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
EOF_CLOUD

  cat >"/tmp/cloudinit-${name}/network-config" <<EOF_NET
version: 2
ethernets:
  ens3:
    dhcp4: false
    addresses:
      - ${ip}/24
    routes:
      - to: default
        via: 192.168.1.1
    nameservers:
      addresses:
        - 192.168.1.1
        - 8.8.8.8
      search:
        - formation.lan
EOF_NET

  cloud-localds -v --network-config="/tmp/cloudinit-${name}/network-config" "$seed" "/tmp/cloudinit-${name}/user-data"
  chown "$REAL_USER":"$REAL_USER" "$seed" || true

  virt-install \
    --name "$name" \
    --memory "$ram" \
    --vcpus "$vcpus" \
    --disk path="$disk",format=qcow2,bus=virtio \
    --disk path="$seed",device=cdrom \
    --os-variant debian12 \
    --import \
    --network network="$LAN_NET_NAME",model=virtio \
    --graphics none \
    --noautoconsole
}

print_summary() {
  cat <<EOF_SUMMARY

============================================================
TP Supervision - création des VMs terminée
============================================================

VM démarrée en premier :
  - ${PFSENSE_VM_NAME}
    WAN : réseau libvirt ${WAN_NET_NAME} en DHCP/NAT
    LAN : réseau libvirt ${LAN_NET_NAME}, attendu en 192.168.1.1/24
    Identifiants labo : admin / pfsense

VMs Debian :
  - srv-web       : 192.168.1.10 / passerelle 192.168.1.1
  - srv-zabbix    : 192.168.1.11 / passerelle 192.168.1.1
  - srv-grafana   : 192.168.1.12 / passerelle 192.168.1.1
  - srv-observium : 192.168.1.13 / passerelle 192.168.1.1

Identifiants Debian cloud-init :
  utilisateur : ${VM_USER}
  mot de passe : ${VM_PASS}

Commandes utiles :
  virsh list --all
  virsh domifaddr ${PFSENSE_VM_NAME}
  virt-viewer ${PFSENSE_VM_NAME}
  ssh ${VM_USER}@192.168.1.10

Si les Debian ne sortent pas vers Internet :
  1. Ouvrir la console pfSense : virt-viewer ${PFSENSE_VM_NAME}
  2. Vérifier que le LAN pfSense est bien 192.168.1.1/24
  3. Vérifier que le WAN est en DHCP sur ${WAN_NET_NAME}
  4. Vérifier que les interfaces pfSense sont dans l'ordre : WAN puis LAN

============================================================
EOF_SUMMARY
}

main() {
  require_root
  require_cmds
  ensure_storage

  create_wan_network
  create_lan_network

  # pfSense est créé et démarré avant les VMs Debian.
  create_pfsense_vm
  wait_for_pfsense

  download_debian_base

  for vm in srv-web srv-zabbix srv-grafana srv-observium; do
    create_debian_vm "$vm"
  done

  print_summary
}

main "$@"
