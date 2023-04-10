# Define function to change network settings
function Set-PSNetworkSettings {
    # New network settings
    $netsettings = [PSCustomObject]@{
        InterfaceAlias = "Internet" # Net adapter name
        IPAddress = "192.168.50.10"
        Gateway = "192.168.50.1"
        PrefixLength = 24 # Subnet mask prefix
        DNSAddresses = "192.168.50.10", "8.8.8.8"
    }

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
    param($SMPass) # Get safe mode administrator password as a parameter
    $domainsettings = [PSCustomObject]@{
        DomainName = "test.local" # DOMAIN NAME
        SafeModePass = $SMPass
    }

    # Create new forest, Install DNS. NO REBOOT as we need to save progress before
    Install-ADDSForest -DomainName $domainsettings.DomainName -InstallDns -SafeModeAdministratorPassword $domainsettings.SafeModePass `
    -NoRebootOnCompletion -Force
}

# Define new DHCP scope function
function New-PSDhcpScope {
    # Scope options
    $dhcpscope = [PSCustomObject]@{
        Name = "test scope"
        StartRange = "192.168.50.100"
        EndRange = "192.168.50.150"
        SubnetMask = "255.255.255.0"
    }
    Add-DhcpServerv4Scope -Name $dhcpscope.Name -StartRange $dhcpscope.StartRange -EndRange $dhcpscope.EndRange `
    -SubnetMask $dhcpscope.SubnetMask
    Set-DhcpServerv4OptionValue -DnsServer 192.168.50.10 -Router 192.168.50.10 -Force
    Add-DhcpServerInDC -DnsName "TESTLAB.test.local" # Authorize in ADDS
}

# Define function to create a new setup.xml file
function New-PSSetupXML {
    # Get credentials and safe mode password
    # The passwords will be stored as securestring
    $cred = Get-Credential -Message "Admin" -UserName Administrator
    $SafeModePass = Read-Host "Safe Mode Administrator Password" -AsSecureString
    
    # Create a new custom object
    $newobject = [PSCustomObject]@{
        Stage = 1
        Status = "Running"
        Credentials = [pscredential]$cred
        SafeModePass = [securestring]$SafeModePass
    }

    # Save the custom object as an xml file
    $newobject | Export-Clixml -Path C:\setup.xml

    # Return the custom object
    return $newobject
}

# Define the main function
function Install-PSDomainController {
    # Check if setup.xml file exists
    if ((Test-Path -Path C:\setup.xml) -eq $false) { # if the file does not exist
        $currentStage = New-PSSetupXML # Create a new setup.xml and assign the content to a variable

        # Create a new scheduled task that runs this script file
        $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:20
        $runasadmin = New-ScheduledJobOption -RunElevated
        Register-ScheduledJob -Credential $currentStage.Credentials -Name SetupDC -Trigger $trigger `
        -ScheduledJobOption $runasadmin -FilePath C:\New-PSDomainController.ps1
    } else {
        # If setup.xml already exists, import it and assign to a variable
        $currentStage = Import-Clixml -Path C:\setup.xml
    }

    switch ($currentStage.Stage) {
        1 { # Start of setup
            # Change network settings
            Set-PSNetworkSettings

            # Install ADDS and DHCP
            Get-WindowsFeature AD-Domain-Services, DHCP | Install-WindowsFeature -IncludeManagementTools
            Rename-Computer -NewName "TESTLAB"

            # Save progress to setup.xml
            $currentStage.Stage = 2
            $currentStage | Export-Clixml C:\setup.xml
            
            # First reboot   
            Restart-Computer -Force
        }
        2 { # Stage 2
            # install new forest, supply safe mode pass as a parameter
            Install-PSNewForest -SMPass $currentStage.SafeModePass
            
            # Save progress   
            $currentStage.Stage = 3
            $currentStage | Export-Clixml C:\setup.xml

            # Change scheduled job trigger
            $newTrigger = New-JobTrigger -AtLogOn
            Get-ScheduledJob -Name SetupDC | Set-ScheduledJob -Trigger $newTrigger
            
            # Second reboot   
            Restart-Computer -Force
        }
        3 { # Final stage
            
            #Create a new dhcp scope and authorize server in ADDS
            New-PSDhcpScope

            # Save progress
            $currentStage.Status = "Complete"
            $currentStage.Stage = 4
            $currentStage | Export-Clixml -Path C:\setup.xml
        }
    }

    # Check for status complete
    if ($currentStage.Status -eq "Complete") {
        # Remove the scheduled job
        Unregister-ScheduledJob -Name SetupDC

        # Remove setup.xml
        Remove-Item -Path C:\setup.xml -Force
    }
}

Install-PSDomainController