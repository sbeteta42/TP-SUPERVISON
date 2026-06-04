# TP Supervision réseau et système — scripts d'installation des VMs

## Topologie cible

| VM | OS | Rôle | IP |
|---|---|---|---|
| pfSense | FreeBSD / pfSense CE | Routeur Internet / passerelle | 192.168.1.1 |
| srv-web | Debian 12 | Apache + MariaDB + Agent Zabbix + SNMP | 192.168.1.10 |
| srv-zabbix | Debian 12 | Zabbix Server + Frontend + Agent | 192.168.1.11 |
| srv-grafana | Debian 12 | Grafana + plugin Zabbix | 192.168.1.12 |
| srv-observium | Debian 12 | Observium Community + MariaDB + Apache | 192.168.1.13 |
| cli-win | Windows 11 | Poste client | 192.168.1.50 |

Réseau : 192.168.1.0/24  
Passerelle : 192.168.1.1  
DNS : 8.8.8.8 ou pfSense

## Ordre d'installation conseillé

1. Installer pfSense et configurer le LAN en `192.168.1.1/24`.
2. Installer les 4 VMs Debian 12 minimales.
3. Sur chaque VM Debian, lancer `linux/00-common-debian12.sh` avec le bon nom et la bonne IP.
4. Lancer ensuite le script de rôle :
   - `linux/10-install-srv-web.sh` sur `srv-web`
   - `linux/20-install-srv-zabbix.sh` sur `srv-zabbix`
   - `linux/30-install-srv-grafana.sh` sur `srv-grafana`
   - `linux/40-install-srv-observium.sh` sur `srv-observium`
5. Sur Windows 11, lancer PowerShell en administrateur puis exécuter :
   - `windows/config-cli-win.ps1`
6. Vérifier :
   - Zabbix : `http://192.168.1.11/zabbix`
   - Grafana : `http://192.168.1.12:3000`
   - Observium : `http://192.168.1.13/observium`
   - Web : `http://192.168.1.10`

## Comptes par défaut pédagogiques

Ces mots de passe sont volontairement simples pour un TP. À changer en environnement réel.

| Service | Compte | Mot de passe |
|---|---|---|
| Zabbix | Admin | zabbix |
| Grafana | admin | admin |
| Observium | admin | Observium1! |
| MariaDB test srv-web | testuser | P@ssw0rd! |
| DB Zabbix | zabbix | ZabbixPass1! |
| DB Observium | observium | Observium1! |

## Remarques importantes

- Les scripts sont prévus pour Debian 12.
- Les scripts doivent être lancés en `root` ou via `sudo`.
- Le script `00-common-debian12.sh` modifie la configuration IP. Lance-le depuis la console VMware/KVM, pas via SSH distant, sinon tu risques de couper ta session.
- Pour Observium, le device `srv-web` est ajouté automatiquement si le SNMP de `srv-web` répond déjà.
- Pour Grafana, le plugin Zabbix est installé. Selon la version, l'application Zabbix peut nécessiter une activation dans l'interface Grafana.
