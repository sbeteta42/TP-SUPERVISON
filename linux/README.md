# 🐧 Scripts Linux Debian 12

![Debian](https://img.shields.io/badge/Debian-12-A81D33?logo=debian&logoColor=white)
![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Monitoring](https://img.shields.io/badge/Supervision-Zabbix%20%7C%20Grafana%20%7C%20Observium-blue)

> 📌 Ce dossier regroupe les scripts d’installation et de préparation des machines **Debian 12** utilisées dans le TP de supervision.

---

## 📂 Contenu du dossier

| Picto | Script | Machine cible | Rôle |
|---|---|---|---|
| ⚙️ | `00-common-debian12.sh` | Toutes les VM Debian | Préparation commune : réseau, paquets, nom d’hôte, prérequis |
| 🌐 | `10-install-srv-web.sh` | `srv-web` | Installation Apache, MariaDB, agent Zabbix et SNMP |
| 📡 | `20-install-srv-zabbix.sh` | `srv-zabbix` | Installation du serveur Zabbix et de son interface web |
| 📊 | `30-install-srv-grafana.sh` | `srv-grafana` | Installation Grafana et plugin Zabbix |
| 🔎 | `40-install-srv-observium.sh` | `srv-observium` | Installation Observium Community, Apache et MariaDB |

---

## 🧭 Ordre d’exécution

### 1️⃣ Préparer chaque VM Debian

À lancer sur chaque serveur Debian :

```bash
sudo bash 00-common-debian12.sh
```

> ⚠️ Ce script peut modifier la configuration IP.  
> Lance-le depuis la **console de virtualisation** plutôt que depuis une session SSH distante.

---

### 2️⃣ Installer le rôle de chaque serveur

#### 🌐 Serveur web supervisé

```bash
sudo bash 10-install-srv-web.sh
```

#### 📡 Serveur Zabbix

```bash
sudo bash 20-install-srv-zabbix.sh
```

#### 📊 Serveur Grafana

```bash
sudo bash 30-install-srv-grafana.sh
```

#### 🔎 Serveur Observium

```bash
sudo bash 40-install-srv-observium.sh
```

---

## 🧱 Machines Linux attendues

| VM | Adresse IP | Service principal | Supervision attendue |
|---|---|---|---|
| 🌐 `srv-web` | `192.168.1.10` | Apache / MariaDB | Agent Zabbix + SNMP |
| 📡 `srv-zabbix` | `192.168.1.11` | Zabbix Server | Interface web Zabbix |
| 📊 `srv-grafana` | `192.168.1.12` | Grafana | Dashboard connecté à Zabbix |
| 🔎 `srv-observium` | `192.168.1.13` | Observium | Découverte SNMP du serveur web |

---

## ✅ Tests rapides

```bash
# Vérifier le nom d’hôte
hostnamectl

# Vérifier l’adresse IP
ip -br a

# Vérifier la passerelle
ip route

# Vérifier la résolution DNS
resolvectl status || cat /etc/resolv.conf

# Vérifier les services actifs
systemctl --type=service --state=running
```

---

## 📡 Tests de supervision

```bash
# Agent Zabbix
systemctl status zabbix-agent zabbix-agent2 2>/dev/null

# SNMP
systemctl status snmpd
snmpwalk -v2c -c <communaute_snmp_lab> 127.0.0.1 system

# Apache
systemctl status apache2
curl -I http://127.0.0.1

# MariaDB
systemctl status mariadb
```

---

## 🛡️ Points d’attention sécurité

- 🔐 Ne pas réutiliser les identifiants de TP en production.
- 📡 Remplacer toute communauté SNMP de test par une valeur robuste.
- 🧱 Restreindre les ports ouverts avec un pare-feu local ou via pfSense.
- 📦 Mettre à jour les paquets après installation.
- 🧾 Documenter les ports, comptes et services activés.

---

## 🧑‍🏫 Utilisation pédagogique

Ce dossier peut servir à faire travailler les apprenants sur :

- la préparation d’un serveur Linux ;
- l’automatisation Bash ;
- la supervision par agent ;
- la supervision SNMP ;
- la recette technique après déploiement ;
- le durcissement post-installation.

---

<p align="center">
  <strong>🐧 Debian 12 — base Linux du laboratoire de supervision</strong>
</p>
