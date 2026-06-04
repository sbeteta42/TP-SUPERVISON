#Requires -RunAsAdministrator
<#
VM cible : cli-win / 192.168.1.50
Usage :
  1. Ouvrir PowerShell en administrateur.
  2. Exécuter :
     Set-ExecutionPolicy Bypass -Scope Process -Force
     .\config-cli-win.ps1

Ce script configure :
- IP statique 192.168.1.50/24
- passerelle 192.168.1.1
- DNS 8.8.8.8 / 1.1.1.1
- fichier hosts pour les VMs du TP
#>

$IPAddress = "192.168.1.50"
$PrefixLength = 24
$Gateway = "192.168.1.1"
$DnsServers = @("8.8.8.8", "1.1.1.1")

Write-Host "[1/5] Détection interface active"
$Adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Sort-Object InterfaceMetric | Select-Object -First 1
if (-not $Adapter) {
    throw "Aucune interface réseau active détectée."
}
$Alias = $Adapter.Name
Write-Host "Interface sélectionnée : $Alias"

Write-Host "[2/5] Nettoyage anciennes IP IPv4 sur l'interface"
Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {$_.IPAddress -ne "127.0.0.1"} |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

Get-NetRoute -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {$_.DestinationPrefix -eq "0.0.0.0/0"} |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "[3/5] Configuration IP statique"
New-NetIPAddress -InterfaceAlias $Alias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $Alias -ServerAddresses $DnsServers

Write-Host "[4/5] Configuration hosts"
$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$Entries = @(
    "192.168.1.1 pfsense",
    "192.168.1.10 srv-web",
    "192.168.1.11 srv-zabbix",
    "192.168.1.12 srv-grafana",
    "192.168.1.13 srv-observium",
    "192.168.1.50 cli-win"
)

$CurrentHosts = Get-Content $HostsPath -ErrorAction SilentlyContinue
foreach ($Entry in $Entries) {
    $Name = ($Entry -split "\s+")[-1]
    if ($CurrentHosts -notmatch "(\s|^)$Name(\s|$)") {
        Add-Content -Path $HostsPath -Value $Entry
    }
}

Write-Host "[5/5] Tests"
Test-Connection 192.168.1.1 -Count 2
Test-Connection 192.168.1.10 -Count 2 -ErrorAction SilentlyContinue
Test-Connection 192.168.1.11 -Count 2 -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "OK : cli-win configuré."
Write-Host "URLs à tester :"
Write-Host "  http://192.168.1.10"
Write-Host "  http://192.168.1.11/zabbix"
Write-Host "  http://192.168.1.12:3000"
Write-Host "  http://192.168.1.13/observium"
