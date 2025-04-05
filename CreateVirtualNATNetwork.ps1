# Define variables for dynamic values
$VirtualSwitchName = "NATSwitch"              # Name of the Hyper-V virtual switch
$HostAdapterName = "vEthernet ($VirtualSwitchName)"  # Auto-generated adapter name
$HostIPAddress = "192.168.100.1"              # Static IP address for the host's virtual adapter
$SubnetPrefixLength = 24                      # Subnet mask length (e.g., 24 = 255.255.255.0)
$NatNetworkName = "NATNetwork"                # Name of the NAT network
$NatIPRange = "192.168.100.0/24"              # IP range for the NAT network

# Step 1: Create or verify the Internal Virtual Switch
if (-not (Get-VMSwitch -Name $VirtualSwitchName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Internal Virtual Switch: $VirtualSwitchName"
    try {
        New-VMSwitch -Name $VirtualSwitchName -SwitchType Internal -ErrorAction Stop
        Write-Host "Virtual Switch created successfully."
    } catch {
        Write-Host "Error creating virtual switch: $_"
        exit
    }
} else {
    Write-Host "Virtual Switch $VirtualSwitchName already exists."
}

# Step 2: Configure the host's virtual network adapter with a static IP
$Adapter = Get-NetAdapter | Where-Object { $_.Name -eq $HostAdapterName }
if ($Adapter) {
    Write-Host "Configuring static IP address $HostIPAddress on $HostAdapterName"
    try {
        # Check if the IP is already assigned to avoid duplicate IP errors
        $ExistingIP = Get-NetIPAddress -InterfaceAlias $HostAdapterName -ErrorAction SilentlyContinue
        if (-not ($ExistingIP -and $ExistingIP.IPAddress -eq $HostIPAddress)) {
            New-NetIPAddress -IPAddress $HostIPAddress -PrefixLength $SubnetPrefixLength -InterfaceAlias $HostAdapterName -ErrorAction Stop
            Write-Host "Static IP assigned successfully."
        } else {
            Write-Host "IP $HostIPAddress is already assigned to $HostAdapterName."
        }
    } catch {
        Write-Host "Error assigning static IP: $_"
        exit
    }
} else {
    Write-Host "Error: Virtual adapter '$HostAdapterName' not found."
    Write-Host "Possible causes:"
    Write-Host "  - The switch '$VirtualSwitchName' didn’t create an adapter (check Hyper-V Manager)."
    Write-Host "  - The adapter name might differ (run 'Get-NetAdapter' to list all adapters)."
    exit
}

# Step 3: Create the NAT network
if (-not (Get-NetNat -Name $NatNetworkName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating NAT network: $NatNetworkName with range $NatIPRange"
    try {
        New-NetNat -Name $NatNetworkName -InternalIPInterfaceAddressPrefix $NatIPRange -ErrorAction Stop
        Write-Host "NAT network created successfully."
    } catch {
        Write-Host "Error creating NAT network: $_"
        exit
    }
} else {
    Write-Host "NAT network $NatNetworkName already exists."
}

# Step 4: Output instructions for VM configuration
Write-Host "NAT configuration complete. To connect a VM:"
Write-Host "1. Set the VM's Network Adapter to use the '$VirtualSwitchName' switch in Hyper-V Manager."
Write-Host "2. Inside the VM, configure the network settings:"
Write-Host "   - IP Address: e.g., 192.168.100.2 (any unique IP in $NatIPRange except $HostIPAddress)"
Write-Host "   - Subnet Mask: 255.255.255.0"
Write-Host "   - Default Gateway: $HostIPAddress"
Write-Host "   - DNS Servers: 8.8.8.8, 8.8.4.4 (or your preferred DNS)"
Write-Host "3. Test internet connectivity from the VM (e.g., 'ping google.com')."