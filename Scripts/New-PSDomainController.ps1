$ScriptFilePath = "C:\New-PSDomainController.ps1"
$XmlFilePath = "C:\setup.xml"

# Define function to create a new setup.xml file
function New-PSSetupXML {
    # Get credentials and safe mode password
    # The passwords will be stored as securestring
    $cred = Get-Credential -Message "Admin" -UserName Administrator
    $SafeModePass = Read-Host "Safe Mode Administrator Password" -AsSecureString
    
    # Creating new Custom objects
    $progressObject = [PSCustomObject]@{
        Name = "Progress"
        Stage = 1
        Status = "Running"
        Credentials = [pscredential]$cred
    }
    # New network settings
    $networkSettings = [PSCustomObject]@{
        Name = "Network"
        InterfaceAlias = "Internet" # Net adapter name
        IPAddress = "192.168.50.10"
        Gateway = "192.168.50.1"
        PrefixLength = 24 # Subnet mask prefix
        DNSAddresses = "192.168.50.10", "8.8.8.8"
    }
    # New Domain Settings
    $domainsettings = [PSCustomObject]@{
        Name = "Domain"
        DomainName = "test.local" # DOMAIN NAME
        SafeModePass = [securestring]$SafeModePass
    }
    # DHCP Scope options
    $dhcpscopesettings = [PSCustomObject]@{
        Name = "DHCP"
        ScopeName = "test scope"
        StartRange = "192.168.50.100"
        EndRange = "192.168.50.150"
        SubnetMask = "255.255.255.0"
    }
    $computerInfo = [PSCustomObject]@{
        Name = "ComputerInfo"
        ComputerName = "TESTLAB"
    }

    # Save the custom objects in an xml file
    $setupobjects = $progressObject, $networkSettings, $domainsettings, $dhcpscopesettings, $computerInfo
    $setupobjects | Export-Clixml -Path $XmlFilePath

    return $setupobjects
}

# Define function to change network settings
function Set-PSNetworkSettings {
    param([Parameter(Mandatory)][PSCustomObject]$netsettings)

    # Check if there is already a network adapter called 'Internet'
    if (!(Get-NetAdapter -Name $netsettings.InterfaceAlias -ErrorAction Ignore)) {Rename-NetAdapter -Name Ethernet -NewName $netsettings.InterfaceAlias}

    # Change IP Address
    try {
        New-NetIPAddress -InterfaceAlias $netsettings.InterfaceAlias -IPAddress $netsettings.IPAddress `
        -DefaultGateway $netsettings.Gateway -PrefixLength $netsettings.PrefixLength -ErrorAction SilentlyContinue
    } catch {}

    # Change DNS address
    Set-DnsClientServerAddress -InterfaceAlias $netsettings.InterfaceAlias `
    -ServerAddresses $netsettings.DNSAddresses
}

# Define New Forest function
function Install-PSNewForest {
    param([Parameter(Mandatory)]$domainsettings)

    # Create new forest, Install DNS. NO REBOOT as we need to save progress before
    Install-ADDSForest -DomainName $domainsettings.DomainName -InstallDns -SafeModeAdministratorPassword $domainsettings.SafeModePass `
    -NoRebootOnCompletion -Force
}

# Define new DHCP scope function
function New-PSDhcpScope {
    param(
        [Parameter(Mandatory)]$dhcpscope,
        [Parameter(Mandatory)][string]$dnsname
    )

    Add-DhcpServerv4Scope -Name $dhcpscope.ScopeName -StartRange $dhcpscope.StartRange -EndRange $dhcpscope.EndRange `
    -SubnetMask $dhcpscope.SubnetMask
    Set-DhcpServerv4OptionValue -DnsServer 192.168.50.10 -Router 192.168.50.10 -Force
    Add-DhcpServerInDC -DnsName $dnsname # Authorize in ADDS
}



# Define the main function
function Install-PSDomainController {
    # Check if setup.xml file exists
    if ((Test-Path -Path C:\setup.xml) -eq $false) { # if the file does not exist
        $setupxml = New-PSSetupXML

        $currentStage = $setupxml | where {$_.Name -eq "Progress"}
        # Create a new scheduled task that runs this script file
        $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:20
        $runasadmin = New-ScheduledJobOption -RunElevated
        Register-ScheduledJob -Credential $currentStage.Credentials -Name SetupDC -Trigger $trigger `
        -ScheduledJobOption $runasadmin -FilePath $ScriptFilePath
    } else {
        $setupxml = Import-Clixml -Path $XmlFilePath
        $currentStage = $setupxml | where {$_.Name -eq "Progress"}
    }

    switch ($currentStage.Stage) {
        1 { # Start of setup
            # Change network settings
            Set-PSNetworkSettings ($setupxml | where {$_.Name -eq "Network"})

            # Install ADDS and DHCP
            Get-WindowsFeature AD-Domain-Services, DHCP | Install-WindowsFeature -IncludeManagementTools
            Rename-Computer -NewName (($setupxml | where {$_.Name -eq "ComputerInfo"}).ComputerName)

            # Save progress to setup.xml
            $currentStage.Stage = 2
            $setupxml | Export-Clixml $XmlFilePath
            
            # First reboot   
            Restart-Computer -Force
        }
        2 { # Stage 2
            # install new forest
            Install-PSNewForest ($setupxml | where {$_.Name -eq "Domain"})
            
            # Save progress   
            $currentStage.Stage = 3
            $setupxml | Export-Clixml $XmlFilePath

            # Change scheduled job trigger
            $newTrigger = New-JobTrigger -AtLogOn
            Get-ScheduledJob -Name SetupDC | Set-ScheduledJob -Trigger $newTrigger
            
            # Second reboot   
            Restart-Computer -Force
        }
        3 { # Final stage
            
            #Create a new dhcp scope and authorize server in ADDS
            $dnsname = "$(($setupxml | where {$_.Name -eq "ComputerInfo"}).ComputerName).$(($setupxml | where {$_.Name -eq "Domain"}).DomainName)"
            New-PSDhcpScope -dhcpscope ($setupxml | where {$_.Name -eq "DHCP"}) -dnsname $dnsname

            # Save progress
            $currentStage.Status = "Complete"
            $currentStage.Stage = 4
            $setupxml | Export-Clixml -Path $XmlFilePath
        }
    }

    # Check for status complete
    if ($currentStage.Status -eq "Complete") {
        # Remove the scheduled job
        Unregister-ScheduledJob -Name SetupDC

        # Remove setup.xml
        Remove-Item -Path $XmlFilePath -Force
    }
}

Install-PSDomainController