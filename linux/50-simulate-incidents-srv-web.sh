#!/usr/bin/env bash
# By Shadowhacker (sbeteta)
set -Eeuo pipefail

# Script de simulation des pannes du TP à exécuter sur srv-web.
# Usage:
#   sudo ./50-simulate-incidents-srv-web.sh apache-down
#   sudo ./50-simulate-incidents-srv-web.sh apache-up
#   sudo ./50-simulate-incidents-srv-web.sh mysql-down
#   sudo ./50-simulate-incidents-srv-web.sh mysql-up
#   sudo ./50-simulate-incidents-srv-web.sh cpu
#   sudo ./50-simulate-incidents-srv-web.sh ssh-fail

ACTION="${1:-help}"

case "$ACTION" in
  apache-down)
    systemctl stop apache2
    echo "Apache arrêté. Attendre la remontée d'alerte Zabbix."
    ;;
  apache-up)
    systemctl start apache2
    echo "Apache redémarré."
    ;;
  mysql-down)
    systemctl stop mariadb
    echo "MariaDB arrêté. Attendre la remontée d'alerte Zabbix."
    ;;
  mysql-up)
    systemctl start mariadb
    echo "MariaDB redémarré."
    ;;
  cpu)
    apt-get update && apt-get install -y stress
    stress --cpu 4 --timeout 120
    ;;
  ssh-fail)
    echo "Simulation locale de tentatives SSH en échec."
    for i in $(seq 1 5); do
      ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=no wrong@127.0.0.1 true || true
    done
    ;;
  *)
    echo "Usage: sudo $0 {apache-down|apache-up|mysql-down|mysql-up|cpu|ssh-fail}"
    exit 1
    ;;
esac
