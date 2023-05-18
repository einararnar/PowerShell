[CmdletBinding()]
param()

$NewVM = @{
    Name = "MSCL01"
    MemoryStartupBytes = (4 * 1gb)
    SwitchName = "LAN"
    Path = "C:\VMs\"
    NewVHDPath = "C:\VMs\MSCL01\VHD\SYS.vhdx"
    NewVHDSizeBytes = 127gb
    Generation = 2
}
$SetVM = @{
    Name = $NewVM.Name
    ProcessorCount = 6
    DynamicMemory = $true
    AutomaticCheckpointsEnabled = $false
    CheckpointType = "Standard"
}
$VMMemory = @{
    VMName = $NewVM.Name
    Buffer = 40
    Priority = 65
}
$DvdDrive = @{
    VMName = $NewVM.Name
    ControllerNumber = 0
    ControllerLocation = 1
    Path = "D:\OS\W10Ex64.iso"
}
#$VMFirmware = @{
#    VMName = "MSCL01"
#    BootOrder = (Get-VMDvdDrive -VMName "MSCL01"), (Get-VMHardDiskDrive -VMName "MSCL01")
#}

if ((Get-VM -Name $NewVM.Name -ErrorAction SilentlyContinue) -eq $null) {
    Write-Verbose "Creating VM: $($NewVM.Name)"
    New-VM @NewVM

    Write-Verbose "Setting VM Settings"
    Set-VM @SetVM
    Set-VMMemory @VMMemory

    Write-Verbose "Adding Dvd drive with ISO file mounted"
    Add-VMDvdDrive @DvdDrive

    Write-Verbose "Setting boot order"
    Set-VMFirmware -VMName $NewVM.Name -BootOrder (Get-VMDvdDrive -VMName $NewVM.Name), (Get-VMHardDiskDrive -VMName $NewVM.Name)
} else {
    Write-Error "A VM with name: $($NewVM.Name), Already exists"
}