# Images OVA / VMware — méthode recommandée

## Base Debian 12

Pour VMware Workstation, le plus simple et le plus propre reste :

1. Installer une VM Debian 12 minimale depuis ISO officielle.
2. Installer `open-vm-tools`.
3. Faire un snapshot `BASE-DEBIAN12`.
4. Cloner la VM 4 fois :
   - srv-web
   - srv-zabbix
   - srv-grafana
   - srv-observium
5. Lancer les scripts Linux fournis.

## Conversion qcow2 vers vmdk

Si tu pars d'une image cloud Debian qcow2 :

```bash
qemu-img convert -f qcow2 -O vmdk debian-12-genericcloud-amd64.qcow2 debian-12-genericcloud-amd64.vmdk
```

Ensuite, créer une VM VMware en utilisant le disque `.vmdk`.

## Export OVA après installation

Une fois la VM prête dans VMware Workstation :

1. Arrêter proprement la VM.
2. `File > Export to OVF...`
3. Obtenir `.ovf` + `.vmdk`.
4. Compresser ou importer ensuite dans un autre hyperviseur compatible.
