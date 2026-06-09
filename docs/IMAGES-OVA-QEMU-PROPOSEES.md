# Images VM proposées pour ce TP

## Recommandation claire

Pour un TP pédagogique stable et reproductible :

- pfSense : ISO officiel pfSense CE, puis export OVA après configuration.
- Debian : image Debian 12 minimale ou image cloud qcow2 officielle.
- Zabbix : soit script Debian fourni, soit appliance officielle Zabbix 7.0 LTS.
- Grafana : Debian 12 + script fourni.
- Observium : Debian 12 + script fourni.
- Windows 11 : ISO d'évaluation Microsoft 90 jours.

## Tableau de choix

| VM | Image conseillée | Format |
|---|---|---|
| pfSense | pfSense CE officiel via Netgate Installer | ISO |
| srv-web | Debian 12 genericcloud ou ISO Debian 12 | qcow2 / ISO |
| srv-zabbix | Debian 12 + script ou Appliance Zabbix 7.0 LTS | qcow2 / OVF / VMX |
| srv-grafana | Debian 12 + script | qcow2 / ISO |
| srv-observium | Debian 12 + script | qcow2 / ISO |
| cli-win | Windows 11 Enterprise Evaluation | ISO |

## À éviter

- Images OVA trouvées sur des sites non officiel **SAUF** celle proposés par votre formateur.
- Appliances anciennes type pfSense 2.4.x sauf besoin GNS3 spécifique.
- Images Observium non maintenues.
- Images Windows non Microsoft.

