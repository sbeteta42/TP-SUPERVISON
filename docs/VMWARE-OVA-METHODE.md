# 🧩 Images OVA / VMware : méthode recommandée

> 🎯 **Objectif** : disposer d’une méthode claire pour importer, préparer, cloner et exporter des machines virtuelles utilisables dans le TP de supervision.

---

## 🚀 Procédure rapide : importer une image `.OVA` avec VMware Workstation

### ✅ Prérequis

Avant l’import, vérifier que vous disposez de :

- 🖥️ **VMware Workstation Pro / Player** installé sur le poste ;
- 📦 une image virtuelle au format `.ova` ;
- 💾 suffisamment d’espace disque disponible ;
- 🌐 les réseaux VMware nécessaires au TP déjà créés ou identifiés ;
- 🔐 les identifiants de connexion de la VM si l’image est préconfigurée.

---

### 📥 Étapes d’import d’une image OVA

1. 📂 Ouvrir **VMware Workstation**.
2. Aller dans le menu :

   ```text
   File > Open...
   ```

3. Sélectionner le fichier `.ova` à importer.
4. Donner un nom explicite à la VM, par exemple :

   ```text
   srv-zabbix
   srv-grafana
   srv-observium
   srv-web
   ```

5. Choisir le dossier de destination de la VM.
6. Cliquer sur **Import**.
7. Si VMware affiche un avertissement de compatibilité OVF/OVA, cliquer sur :

   ```text
   Retry / Réessayer
   ```

   sauf si l’erreur indique clairement une image corrompue.

8. Une fois l’import terminé, ouvrir les **Settings** de la VM.
9. Vérifier les ressources :

   - ⚙️ CPU ;
   - 🧠 RAM ;
   - 💽 disque ;
   - 🌐 cartes réseau ;
   - 🔌 ordre de démarrage.

10. Adapter la carte réseau selon le rôle de la VM :

| VM | Réseau recommandé |
|---|---|
| `srv-web` | `LAN-SUPERVISION` |
| `srv-zabbix` | `LAN-SUPERVISION` |
| `srv-grafana` | `LAN-SUPERVISION` |
| `srv-observium` | `LAN-SUPERVISION` |
| `pfSense` WAN | NAT / Bridge Internet |
| `pfSense` LAN | `LAN-SUPERVISION` |

11. Démarrer la VM.
12. Vérifier l’adresse IP, le nom d’hôte et la connectivité réseau.
13. Créer immédiatement un snapshot propre :

```text
IMPORT-OVA-OK
```

---

### 🧪 Vérifications après import

Depuis la VM importée :

```bash
ip a
hostnamectl
ping 192.168.1.1
ping 8.8.8.8
```

Depuis une autre VM du TP :

```bash
ping 192.168.1.10
ping 192.168.1.11
ping 192.168.1.12
ping 192.168.1.13
```

---

### ⚠️ Points de vigilance

- 🧬 Ne pas démarrer deux clones ayant le même hostname et la même adresse IP.
- 🌐 Vérifier que les cartes réseau sont bien connectées au bon réseau VMware.
- 🔐 Changer les mots de passe par défaut si l’image est fournie préconfigurée.
- 🧹 Supprimer les anciennes règles DHCP ou IP statiques si l’image vient d’un autre lab.
- 📸 Faire un snapshot avant toute modification importante.

---

## 🐧 Base Debian 12

Pour VMware Workstation, le plus simple et le plus propre reste :

1. 💿 Installer une VM Debian 12 minimale depuis l’ISO officielle.
2. 🧰 Installer `open-vm-tools`.
3. 📸 Faire un snapshot :

   ```text
   BASE-DEBIAN12
   ```

4. 🧬 Cloner la VM 4 fois :

   - 🌐 `srv-web`
   - 📊 `srv-zabbix`
   - 📈 `srv-grafana`
   - 🔎 `srv-observium`

5. ▶️ Lancer les scripts Linux fournis.

---

## 🛠️ Installation des VMware Tools sous Debian

Sur chaque VM Debian :

```bash
sudo apt update
sudo apt install -y open-vm-tools open-vm-tools-desktop
sudo reboot
```

Pour un serveur sans interface graphique, `open-vm-tools` suffit généralement :

```bash
sudo apt install -y open-vm-tools
```

---

## 🔁 Conversion `qcow2` vers `vmdk`

Si vous partez d’une image cloud Debian au format `qcow2` :

```bash
qemu-img convert -f qcow2 -O vmdk debian-12-genericcloud-amd64.qcow2 debian-12-genericcloud-amd64.vmdk
```

Ensuite :

1. 🖥️ Créer une nouvelle VM VMware.
2. Choisir **I will install the operating system later**.
3. Sélectionner **Linux / Debian 12.x 64-bit**.
4. Supprimer le disque généré automatiquement si nécessaire.
5. Ajouter le disque `.vmdk` converti.
6. Démarrer la VM.

---

## 📤 Export OVA après installation

Une fois la VM prête dans VMware Workstation :

1. 🛑 Arrêter proprement la VM.
2. Vérifier que la VM ne contient pas de snapshot inutile.
3. Nettoyer les caches si nécessaire :

   ```bash
   sudo apt clean
   sudo journalctl --vacuum-time=1d
   ```

4. Depuis VMware Workstation :

   ```text
   File > Export to OVF...
   ```

5. Obtenir les fichiers :

   - `.ovf`
   - `.vmdk`
   - éventuellement `.mf`

6. 📦 Compresser les fichiers exportés si besoin.
7. Tester l’import dans un autre VMware Workstation avant diffusion.

---

## 📋 Checklist finale avant diffusion d’une image

| Contrôle | État attendu |
|---|---|
| Hostname | unique et cohérent |
| Adresse IP | conforme au plan d’adressage |
| Réseau VMware | correctement associé |
| `open-vm-tools` | installé |
| Mots de passe | changés ou documentés |
| Services | activés au démarrage |
| Snapshot | propre et nommé |
| Import test | validé |

---

## 🧠 Recommandation pédagogique

Pour un TP de supervision, il est préférable d'utiliser :

- une base Debian 12 propre ;
- des snapshots nommés par étape ;
- une documentation claire des IP, comptes et services.
