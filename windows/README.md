# 💻 Poste client Windows 11

![Windows](https://img.shields.io/badge/Windows-11-0078D4?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-Admin-5391FE?logo=powershell&logoColor=white)
![Client](https://img.shields.io/badge/R%C3%B4le-Client%20de%20test-blue)

> 📌 Ce dossier contient la configuration du poste **Windows 11** utilisé pour tester l’accès aux interfaces web et valider le bon fonctionnement du laboratoire de supervision.

---

## 🎯 Rôle du client Windows

Le poste `cli-win` sert à :

- 💻 accéder aux interfaces web Zabbix, Grafana et Observium ;
- 🌐 tester la connectivité vers les serveurs Debian ;
- 🧪 réaliser les captures de recette ;
- 🔎 vérifier les ports et les services exposés ;
- 🧑‍🏫 jouer le rôle du poste apprenant ou administrateur junior.

---

## 🧱 Paramètres attendus

| Élément | Valeur |
|---|---|
| Nom de machine | `cli-win` |
| OS | Windows 11 |
| Adresse IP | `192.168.1.50` |
| Masque | `/24` |
| Passerelle | `192.168.1.1` |
| DNS | pfSense ou DNS externe pédagogique |

---

## 🚀 Exécution du script

Ouvrir **PowerShell en administrateur**, puis lancer :

```powershell
.\config-cli-win.ps1
```

> ⚠️ Le script doit être lancé avec les droits administrateur pour appliquer correctement la configuration système et réseau.

---

## ✅ Tests à réaliser depuis Windows

### 🌐 Tests web

| Service | URL | Résultat attendu |
|---|---|---|
| Serveur web | `http://192.168.1.10` | Page web accessible |
| Zabbix | `http://192.168.1.11/zabbix` | Page de connexion Zabbix |
| Grafana | `http://192.168.1.12:3000` | Page de connexion Grafana |
| Observium | `http://192.168.1.13/observium` | Page de connexion Observium |

---

### 🧪 Tests PowerShell utiles

```powershell
# Vérifier l’adresse IP
ipconfig /all

# Tester la passerelle
Test-Connection 192.168.1.1

# Tester les serveurs Linux
Test-Connection 192.168.1.10
Test-Connection 192.168.1.11
Test-Connection 192.168.1.12
Test-Connection 192.168.1.13

# Tester les ports web
Test-NetConnection 192.168.1.10 -Port 80
Test-NetConnection 192.168.1.11 -Port 80
Test-NetConnection 192.168.1.12 -Port 3000
Test-NetConnection 192.168.1.13 -Port 80
```

---

## 🖼️ Captures attendues pour la recette

Les apprenants peuvent fournir les captures suivantes :

- 📸 `ipconfig /all` du poste Windows ;
- 📸 ping réussi vers pfSense ;
- 📸 ping réussi vers chaque serveur Debian ;
- 📸 accès à l’interface Zabbix ;
- 📸 accès à l’interface Grafana ;
- 📸 accès à l’interface Observium ;
- 📸 accès au serveur web `srv-web`.

---

## 🛡️ Bonnes pratiques

- 🔐 Ne pas enregistrer les mots de passe de TP dans le navigateur.
- 🧹 Nettoyer l’historique si le poste est partagé.
- 🧱 Restreindre les flux depuis pfSense si le TP évolue vers un scénario de durcissement.
- 🧾 Documenter les tests réalisés dans une fiche de recette.

---

## 🧑‍🏫 Exploitation pédagogique

Ce poste est idéal pour évaluer :

- la lecture d’une configuration IP ;
- la validation d’une connectivité réseau ;
- l’accès aux interfaces d’administration ;
- l’analyse simple de ports ouverts ;
- la production de captures propres pour un compte rendu de TP.

---

<p align="center">
  <strong>💻 Windows 11 : poste de test et de validation du laboratoire</strong>
</p>
