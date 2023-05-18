$computerName = 'computer1', 'computer2', 'computer3'

$cimParam = @{
    CimSession  = New-CimSession -ComputerName $computerName -SessionOption (New-CimSessionOption -Protocol Dcom)
    ClassName = 'Win32_Process'
    MethodName = 'Create'
    Arguments = @{ CommandLine = 'cmd.exe /c winrm quickconfig' }
}

Invoke-CimMethod @cimParam