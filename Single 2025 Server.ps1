$labName = 'SingleMachine'
$servername = 'TestServer'
#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

#make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.70.0/24

Set-LabInstallationCredential -Username Install -Password Somepass1

#Our one and only machine with nothing on it
Add-LabMachineDefinition -Name $servername -Memory 1GB -Network $labName -IpAddress 192.168.70.11 `
    -OperatingSystem 'Windows Server 2025 Datacenter (Desktop Experience)'

Install-Lab

#Install software to all lab machines
#$packs = @()
#$packs += Get-LabSoftwarePackage -Path $labSources\SoftwarePackages\PingCastle\PingCastle.exe -CommandLine /S
#$packs += Get-LabSoftwarePackage -Path $labSources\SoftwarePackages\PurpleKnightCommunity\PurpleKnight.exe -CommandLine /S

#Install-LabSoftwarePackages -Machine (Get-LabVM -All) -SoftwarePackage $packs
Copy-LabFileItem -Path $labSources\SoftwarePackages\PingCastle\ -ComputerName $servername -DestinationFolderPath C:\Temp
Copy-LabFileItem -Path $labSources\SoftwarePackages\PurpleKnightCommunity\ -ComputerName $servername -DestinationFolderPath C:\Temp

Show-LabDeploymentSummary
