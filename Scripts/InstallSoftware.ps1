$tempdest = "C:\Windows\Temp\"
# Get OS 64-bit/32-bit
$osarchitecture = Get-ComputerInfo | select OsArchitecture

# List of software to install
$programList = @{
    Python = @{ # Python 3.11
        X64 = "python-3.11.1-amd64.exe" # 64-bit
        X32 = "python-3.11.1.exe" # 32-bit
        UNC = "\\MSDC01\SoftwareDeployment\" # UNC FILE LOCATION
        ARGS = "/quiet InstallAllUsers=1" # ARGUMENTS
        Installed = "C:\Windows\py.exe"
    }

    VSC = @{ # VS Code
        X64 = "VSCodeSetup-x64-1.74.0.exe"
        X32 = "VSCodeSetup-ia32-1.74.0.exe"
        UNC = "\\MSDC01\SoftwareDeployment\"
        ARGS = "/VERYSILENT /MERGETASKS=!runcode /DIR C:\VSCode"
        Installed = "C:\Program Files\Microsoft VS Code\Code.exe"
    }
}


switch ($osarchitecture.OsArchitecture) {
    # IF SYSTEM IS 64-BIT
    "64-bit" {
        foreach ($program in $programList.Values) {
            $uncpath = $program.UNC+$program.X64
            # Check if install file is in C:\Windows\Temp
            if (-not (Test-Path "$tempdest$program.X64")) {
                # Copy to Temp
                copy $uncpath $tempdest
            }

            # Check if software is not installed
            if (-not (Test-Path $program.Installed)) {
                # Run the installation program with specified arguments
                # Runs the 64-bit installer
                start $uncpath $program.ARGS -Wait 
            }
            
        }
    }
    # IF SYSTEM IS 32-BIT
    "32-bit" {
        foreach ($program in $programList.Values) {
            $uncpath = $program.UNC+$program.X32
            # Copy installation files from UNC to temporary destination
            # Copy-Item
            if (-not (Test-Path "$tempdest$program.X32")) {
                copy $uncpath $tempdest
            }
    
            if (-not (Test-Path $program.Installed)) {
                # Run the installation program with specified arguments
                # Runs the 32-bit installer
                start $uncpath $program.ARGS -Wait 
            }
        }
    }
}



    
 
# Windows\Temp Cleanup after installation

# Remove python log files
$tempfiles = dir "C:\Windows\Temp\" | where Name -Like "Python*.log"
$tempfiles | % {del $_.FullName}

# Remove exe files
$exefiles = dir "C:\Windows\Temp\" | where Name -Like "*.exe"
$exefiles | % {del $_.FullName}
