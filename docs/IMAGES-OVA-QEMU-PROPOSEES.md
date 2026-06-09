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
| pfSense | pfSense CE officiel via Netgate Installer | ISO/ [OVA](https://mega.nz/file/f15BVSjI#eO5j5LTHVih6ZJYeDwh_Ljq4gOmcVg42G-viHiTPHk4)|
| srv-web | Debian 12 genericcloud ou ISO Debian 12 | [qcow2](https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2) / [ISO](https://cdimage.debian.org/cdimage/archive/12.13.0/amd64/iso-cd/debian-12.13.0-amd64-netinst.iso) / [OVA](https://mega.nz/file/egRGlZxR#N76D0EHWaud6MtELHjeR4s6pciZ5jRRsz_N_JihF8Hk) |
| srv-zabbix | Debian 12 + script ou Appliance Zabbix 7.0 LTS | [qcow2](https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2) / OVF / VMX |
| srv-grafana | Debian 12 + script | [qcow2](https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2) [ISO](https://cdimage.debian.org/cdimage/archive/12.13.0/amd64/iso-cd/debian-12.13.0-amd64-netinst.iso) / [OVA](https://mega.nz/file/egRGlZxR#N76D0EHWaud6MtELHjeR4s6pciZ5jRRsz_N_JihF8Hk) |
| srv-observium | Debian 12 + script | qcow2](https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2) / [ISO](https://cdimage.debian.org/cdimage/archive/12.13.0/amd64/iso-cd/debian-12.13.0-amd64-netinst.iso) |
| cli-win | Windows 11 Enterprise Evaluation | [ISO](https://mega.nz/file/D8Y2DZSZ#BxxiD6MLqFU_9GlSUZt6bxtUNZ1CoW5RwcgW-5aLm9g) / [OVA](https://mega.nz/file/C8wFkCKR#WF0raTNtvUWZIH-ocUj4IUWMelca-gUiX6UUJbQpAIA) |

## À éviter

- Images OVA trouvées sur des sites non officiel **SAUF** celle proposés par votre formateur.
- Appliances anciennes type pfSense 2.4.x sauf besoin GNS3 spécifique.
- Images Observium non maintenues.
- Images Windows non Microsoft.

