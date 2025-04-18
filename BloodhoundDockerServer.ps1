$labName = 'BloodhoundDocker'
$clientname1 = 'Assessment1'
#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

#make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -HyperVProperties @{SwitchType = 'External'; AdapterName = 'Wi-Fi'}

Set-LabInstallationCredential -Username Install -Password Somepass1

#Our one and only machine with nothing on it
Add-LabMachineDefinition -Name $clientname1 -Processors 8 -Memory 8GB -Network $labName `
    -OperatingSystem 'Windows Server 2025 Datacenter (Desktop Experience)'

Install-Lab

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
#Invoke-LabCommand -ActivityName "Run Docker Compose Pull" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\Program Files\Docker\Docker\resources\bin\docker-compose.exe" -ArgumentList "-f C:\AssessmentTools\Bloodhound\docker-compose.yml pull >> C:\AssessmentTools\Bloodhound\DockerComposePullLog.txt" -Wait } -PassThru
#Invoke-LabCommand -ActivityName "Run Docker Compose Pull" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\AssessmentTools\Bloodhound\dockerPull.cmd" -Wait } -PassThru


#Run Docker Container
#Invoke-LabCommand -ActivityName "Run Docker Compose Up" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\Program Files\Docker\Docker\resources\bin\docker-compose.exe" -ArgumentList "-f C:\AssessmentTools\Bloodhound\docker-compose.yml up >> C:\AssessmentTools\Bloodhound\DockerComposeUpLog.txt" -Wait } -PassThru
#Invoke-LabCommand -ActivityName "Run Docker Compose Up" -ComputerName $clientname1 -ScriptBlock { Start-Process -FilePath "C:\AssessmentTools\Bloodhound\dockerUp.cmd"} -PassThru

Show-LabDeploymentSummary