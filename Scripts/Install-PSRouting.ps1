Get-WindowsFeature -Name Routing | Install-WindowsFeature -IncludeManagementTools
Install-RemoteAccess -VpnType RoutingOnly
New-NetNat -Name "NAT-LAN" -InternalIPInterfaceAddressPrefix 192.168.50.0/24

Restart-Computer -Force
