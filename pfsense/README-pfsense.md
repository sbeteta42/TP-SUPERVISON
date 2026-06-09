# pfSense — préparation de la VM du TP

## Image recommandée

Utiliser l'ISO officiel pfSense CE via Netgate Installer.

## Paramètres VM VMware / KVM

- OS invité : FreeBSD 64-bit
- CPU : 1 vCPU
- RAM : 1 Go minimum
- Disque : 10 Go
- NIC 1 : WAN, NAT ou bridge Internet
- NIC 2 : LAN, réseau interne `LAN-SUPERVISION`

## Configuration pfSense attendue

| Interface | Rôle | IP |
|---|---|---|
| WAN | Internet | DHCP |
| LAN | Réseau TP | 192.168.1.1/24 |

## Étapes rapides

1. Installer pfSense depuis l'ISO.
2. Assigner les interfaces :
   - WAN : interface connectée à Internet/NAT.
   - LAN : interface connectée au réseau interne des VMs.
3. Configurer LAN :
   - IP : `192.168.1.1`
   - Masque : `/24`
   - DHCP : désactivé pour respecter le TP en IP fixe.
4. Depuis `cli-win`, accéder à :
   - `https://192.168.1.1`
5. Identifiants par défaut pfSense :
   - `admin`
   - `pfsense`
6. Changer le mot de passe dès le premier accès.
7. Vérifier que les VMs Debian sortent vers Internet via pfSense :
   - `ping 8.8.8.8`
   - `apt update`

## Règles firewall LAN conseillées pour le TP

Sur l'interface LAN, autoriser temporairement :

- LAN net -> any : IPv4 any, pour simplifier l'installation.
- Puis durcir ensuite :
  - DNS : UDP/TCP 53
  - HTTP/HTTPS : TCP 80/443
  - NTP : UDP 123
  - SSH interne : TCP 22
  - Zabbix agent/server : TCP 10050/10051
  - SNMP : UDP 161 depuis `srv-observium` et/ou `srv-zabbix`

## Snapshot conseillé

Créer un snapshot nommé :

`pfSense-LAN-192.168.1.1-BASE`

avant de démarrer l'installation des autres VMs.
