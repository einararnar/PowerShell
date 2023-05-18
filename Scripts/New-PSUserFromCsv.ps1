param(
    [parameter(Mandatory=$true)][string] $Path
)
cls
try {
    $users = Import-Csv "$Path" -ErrorAction Stop
} catch {
    Write-Warning "CSV Not found Location: $Path"
}
$forest = "OU=People,OU=ORG,DC=einaram,DC=local"
$userpass = Read-Host "Enter Password users" -AsSecureString
foreach ($user in $users) {
    $department = $user.Department

    if ((Get-ADOrganizationalUnit -SearchBase $forest -Filter {name -like $department}).Name -ne $user.Department) {
        # Create department OU and Group if it does not exist
        New-ADOrganizationalUnit -Name $department -Path $forest -ProtectedFromAccidentalDeletion $false
        New-ADGroup -Name $department -GroupScope Global -Path "OU=$department,$forest"
        Add-ADGroupMember -Identity "All Domain Users" -Members $department
    }
    $name = $user.FullName
    $nameSplit = $name.Split(' ')

    # Get first 3 letters in first name
    if ($nameSplit[0].Length -ge 3) {
        $first3 = $nameSplit[0].Substring(0, 3)
    } else {
        $first3 = $nameSplit[0].Substring(0, $nameSplit[0].Length)
    }

    # Get first 3 letters in last name
    if ($nameSplit[-1].Length -ge 3) {
        $last3 = $nameSplit[-1].Substring(0, 3)
    } else {
        $last3 = $nameSplit[-1].Substring(0, $nameSplit[0].Length)
    }
    $last4id = ($user.ID).Split("-")
    $username = $first3.ToLower()+$last3.ToLower()+$last4id[1]
        
    New-ADUser -Name $name -DisplayName $name -GivenName $nameSplit[0] -Surname $nameSplit[-1] `
    -AccountPassword $userpass -ChangePasswordAtLogon $false -Department $department -Description $department `
    -EmployeeID $user.ID -Country "IS" -Enabled $true -Path "OU=$department,$forest" -SamAccountName $username `
    -Title $department -UserPrincipalName "$username@eam1.ntv"

    Add-ADGroupMember -Identity $department -Members $username

    # IT staff members get an extra administrator account
    if ($department -eq "IT") {
        New-ADUser -Name $name" (Admin)" -DisplayName $name" (Admin)" -GivenName $nameSplit[0] -Surname $nameSplit[-1] `
        -AccountPassword $userpass -ChangePasswordAtLogon $false -Department $department -Description $department" Administrator account" `
        -EmployeeID $user.ID -Country "IS" -Enabled $true -Path "OU=$department,$forest" -SamAccountName $username".admin" `
        -Title $department -UserPrincipalName $username".admin@eam1.ntv"

        Add-ADGroupMember -Identity $department -Members $username".admin"
        Add-ADGroupMember -Identity "SysAdmins" -Members $username".admin"
    }
}