$labName = 'SCADSecurityLab'
$clientname1 = 'AssessmentSrv1'
#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

#make the network definition
Add-LabVirtualNetworkDefinition -Name NATSwitch -AddressSpace 192.168.100.0/24 #-HyperVProperties @{SwitchType = 'External'; AdapterName = 'Wi-Fi'}

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name sovereigncyber.de -AdminUser DA -AdminPassword Somepass1
#Add-LabDomainDefinition -Name emea.sovereigncyber.de -AdminUser DA -AdminPassword Somepass1
#Add-LabDomainDefinition -Name b.forest1.net -AdminUser Install -AdminPassword Somepass1
#Add-LabDomainDefinition -Name forest2.net -AdminUser Install -AdminPassword Somepass2
#Add-LabDomainDefinition -Name forest3.net -AdminUser Install -AdminPassword Somepass3

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:ToolsPath'= "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem'= 'Windows Server 2025 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'= 8096MB
    'Add-LabMachineDefinition:Processors' = 4
}

#--------------------------------------------------------------------------------------------------------------------
Set-LabInstallationCredential -Username DA -Password Somepass1

#Now we define the domain controllers of the first forest. This forest has two child domains.
$role = Get-LabMachineRoleDefinition -Role RootDC @{
    ForestFunctionalLevel = 'WinThreshold'
    DomainFunctionalLevel = 'WinThreshold'
    SiteName = 'Frankfurt'
    SiteSubnet = '192.168.100.0/24'
}
Add-LabMachineDefinition -Name SCRDC01 -DomainName sovereigncyber.de -IPAddress 192.168.100.10 -Gateway 192.168.100.1 -Roles $role

#Child Domain Controller
#$role = Get-LabMachineRoleDefinition -Role FirstChildDC @{
#    ParentDomain = 'sovereigncyber.de'
#    NewDomain = 'emea'
#    DomainFunctionalLevel = 'WinThreshold'
#    SiteName = 'London'
#    SiteSubnet = '192.168.50.0/24'
#}
#Add-LabMachineDefinition -Name SCCDC01 -DomainName emea.sovereigncyber.de -IpAddress 192.168.50.10 -DnsServer1 192.168.50.10 -Gateway 192.168.100.1 -Roles $role

#Install Member Server to run assessments from
Add-LabMachineDefinition -Name $clientname1 -DomainName sovereigncyber.de -IPAddress 192.168.100.100 -Gateway 192.168.100.1 -DnsServer1 192.168.100.10

Install-Lab

#Set DNS Forwarder
Invoke-LabCommand -ActivityName "Set DNS Forwarder to 1.1.1.1" -ComputerName SCRDC01 -ScriptBlock { Set-DnsServerForwarder -IPAddress "1.1.1.1" -PassThru } -PassThru

#Copy Assessment Tools
Copy-LabFileItem -Path $labSources\AssessmentTools\PingCastle\ -ComputerName $clientname1 -DestinationFolderPath C:\AssessmentTools
Copy-LabFileItem -Path $labSources\AssessmentTools\PurpleKnightCommunity\ -ComputerName $clientname1 -DestinationFolderPath C:\AssessmentTools
Copy-LabFileItem -Path $labSources\AssessmentTools\Bloodhound\ -ComputerName $clientname1 -DestinationFolderPath C:\AssessmentTools

#Enable Nested Virtualisation
Stop-LabVM -ComputerName $clientname1 -wait
Get-VM $clientname1 | Set-VMProcessor -ExposeVirtualizationExtensions $true
Start-LabVM -ComputerName $clientname1 -wait
Wait-LabVM -ComputerName $clientname1

#Enable WSL in VM
Invoke-LabCommand -ActivityName "Install WSL-2" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "wsl.exe" -ArgumentList "--install --no-distribution" -Wait -NoNewWindow } -PassThru
Restart-LabVM -ComputerName $clientname1 -wait
Wait-LabVM -ComputerName $clientname1 

#Install Docker
Invoke-LabCommand -ActivityName "Install Docker Desktop" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\AssessmentTools\Bloodhound\Docker Desktop Installer.exe" -ArgumentList "install --quiet --accept-license --backend=wsl-2 --always-run-service" -Wait -NoNewWindow }  -Retries 2 -PassThru
Wait-LabVM -ComputerName $clientname1
Restart-LabVM -ComputerName $clientname1 -wait
Wait-LabVM -ComputerName $clientname1

#Download Docker images
Invoke-LabCommand -ActivityName "Run Docker Compose Pull" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\Program Files\Docker\Docker\resources\bin\docker-compose.exe" -ArgumentList "-f C:\AssessmentTools\Bloodhound\docker-compose.yml pull >> C:\AssessmentTools\Bloodhound\DockerComposePullLog.txt" -Wait } -PassThru
Invoke-LabCommand -ActivityName "Run Docker Compose Pull" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\AssessmentTools\Bloodhound\dockerPull.cmd" -Wait } -PassThru

#Run Docker Container
Invoke-LabCommand -ActivityName "Run Docker Compose Up" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\Program Files\Docker\Docker\resources\bin\docker-compose.exe" -ArgumentList "-f C:\AssessmentTools\Bloodhound\docker-compose.yml up >> C:\AssessmentTools\Bloodhound\DockerComposeUpLog.txt" -Wait } -PassThru
Invoke-LabCommand -ActivityName "Run Docker Compose Up" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\AssessmentTools\Bloodhound\dockerUp.cmd"} -PassThru

Show-LabDeploymentSummary
