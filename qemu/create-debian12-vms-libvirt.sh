#!/usr/bin/env bash
set -Eeuo pipefail

# Script de préparation QEMU/KVM/libvirt pour le TP.
# Il crée un réseau LAN isolé et prépare les disques Debian 12 qcow2.
#
# À adapter :
#   - STORAGE_DIR
#   - LAN_NET_NAME
#   - WAN_NET_NAME
#
# Pré-requis Debian/Ubuntu host :
#   sudo apt install -y qemu-kvm libvirt-daemon-system virtinst virt-manager cloud-image-utils qemu-utils wget

STORAGE_DIR="${STORAGE_DIR:-/home/$USER/tp-supervision}"
LAN_NET_NAME="${LAN_NET_NAME:-LAN}"
WAN_NET_NAME="${WAN_NET_NAME:-NAT}"
DEBIAN_IMG_URL="${DEBIAN_IMG_URL:-https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2}"
DEBIAN_BASE="${STORAGE_DIR}/debian-12-genericcloud-amd64.qcow2"

VM_USER="${VM_USER:-admin}"
VM_PASS="${VM_PASS:-operations}"

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

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "ERREUR: lancer avec sudo."
    exit 1
  fi
}

create_lan_network() {
  if virsh net-info "$LAN_NET_NAME" >/dev/null 2>&1; then
    echo "Réseau libvirt $LAN_NET_NAME déjà présent."
    return
  fi

  cat >/tmp/${LAN_NET_NAME}.xml <<EOF
<network>
  <name>${LAN_NET_NAME}</name>
  <bridge name='virbr-superv' stp='on' delay='0'/>
  <ip address='192.168.1.254' netmask='255.255.255.0'>
  </ip>
</network>
EOF

  virsh net-define /tmp/${LAN_NET_NAME}.xml
  virsh net-start "$LAN_NET_NAME"
  virsh net-autostart "$LAN_NET_NAME"
}

download_base() {
  mkdir -p "$STORAGE_DIR"
  if [[ ! -f "$DEBIAN_BASE" ]]; then
    wget -O "$DEBIAN_BASE" "$DEBIAN_IMG_URL"
  fi
}

create_vm() {
  local name="$1"
  local ip="${IPS[$name]}"
  local ram="${RAMS[$name]}"
  local vcpus="${VCPUS[$name]}"
  local disk="${STORAGE_DIR}/${name}.qcow2"
  local seed="${STORAGE_DIR}/${name}-seed.iso"

  if virsh dominfo "$name" >/dev/null 2>&1; then
    echo "VM $name déjà présente, ignorée."
    return
  fi

  qemu-img create -f qcow2 -F qcow2 -b "$DEBIAN_BASE" "$disk" 30G

  local pass_hash
  pass_hash="$(openssl passwd -6 "$VM_PASS")"

  mkdir -p "/tmp/cloudinit-${name}"
  cat >"/tmp/cloudinit-${name}/user-data" <<EOF
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
timezone: Europe/Paris
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF

  cat >"/tmp/cloudinit-${name}/network-config" <<EOF
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
        - 8.8.8.8
        - 1.1.1.1
EOF

  cloud-localds -v --network-config="/tmp/cloudinit-${name}/network-config" "$seed" "/tmp/cloudinit-${name}/user-data"

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

main() {
  require_root
  create_lan_network
  download_base

  for vm in srv-web srv-zabbix srv-grafana srv-observium; do
    create_vm "$vm"
  done

  echo
  echo "OK: VMs Debian créées."
  echo "Important: installer pfSense avec LAN 192.168.1.1 sur le même réseau ${LAN_NET_NAME}, sinon les VMs n'auront pas de passerelle."
  echo "Utilisateur cloud-init : ${VM_USER}"
  echo "Mot de passe pédagogique : ${VM_PASS}"
}

main "$@"
