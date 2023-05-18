$usercsvpath = "C:\users.csv"

$standardpassword = Read-Host "Standard user passwords" -AsSecureString
$adminpassword = Read-Host "Administrative passwords" -AsSecureString

# CREATE OU 
if((Get-ADOrganizationalUnit -Filter "Name -eq 'ORG'") -eq $null) {
    New-ADOrganizationalUnit -Name "ORG" -ProtectedFromAccidentalDeletion $true

    New-ADOrganizationalUnit -Name "Users" -Path "OU=ORG,DC=einsi,DC=local" -ProtectedFromAccidentalDeletion $false
    New-ADOrganizationalUnit -Name "Machines" -Path "OU=ORG,DC=einsi,DC=local" -ProtectedFromAccidentalDeletion $false

    New-ADGroup -Name "All Domain Users" -Path "OU=Users,OU=ORG,DC=einsi,DC=local" -GroupScope Global
}

try {
    $users = Import-Csv -Path $usercsvpath
} catch{
    Write-Error -Message "File $usercsvpath not found"
}

$userpath = "OU=Users,OU=ORG,DC=einsi,DC=local"
foreach($user in $users) {
    if ((Get-ADGroup -Filter "Name -eq '$($user.Department)'") -eq $null) {
        if ($user.Department -eq "IT") {
            New-ADGroup -Name "IT Admins" -Path $userpath -GroupScope Global -PassThru | `
            Add-ADPrincipalGroupMembership -MemberOf "Domain Admins","Protected Users"
        }
        New-ADGroup -Name $user.Department -GroupScope Global -Path $userpath
    }

    $names = $user.FullName.Split(" ")
    $samaccountname = $user.FullName.Replace(" ",".").ToLower()

    New-ADUser -Name $user.FullName -DisplayName $user.FullName -GivenName $names[0] -Surname $names[-1] `
    -ChangePasswordAtLogon $true -Department $user.Department -Enabled $true -SamAccountName $samaccountname `
    -UserPrincipalName "$($samaccountname)@einsi.local" -AccountPassword $standardpassword `
    -Path $userpath -Description "Standard user login" -PassThru | `
    Add-ADPrincipalGroupMembership -MemberOf $user.Department, "All Domain Users"

    if ($user.Department -eq "IT") {
        New-ADUser -Name "$($user.FullName) (ADMIN)" -DisplayName "$($user.FullName) (ADMIN)" -GivenName $names[0] -Surname $names[-1] `
        -ChangePasswordAtLogon $true -Department $user.Department -Enabled $true -SamAccountName "$($samaccountname).admin" `
        -UserPrincipalName "$($samaccountname).admin@einsi.local" -AccountPassword $adminpassword -Path $userpath `
        -Description "Domain Administrative login" -PassThru | `
        Add-ADPrincipalGroupMembership -MemberOf "IT Admins","All Domain Users"
    }
}