Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#Check for Azure Ad Connection
try {
    $connection = Get-AzureADCurrentSessionInfo -ErrorAction Ignore
} catch {
    $connection = $null
}

$main = New-Object System.Windows.Forms.Form
$main.StartPosition = "CenterScreen"
$main.Size = New-Object System.Drawing.Size(800,800)
$main.Text = "Azure Ad Control Tool"

# Connect to Azure Ad Button
if ($connection -eq $null) {
    $connect_button = New-Object System.Windows.Forms.Button
    $connect_button.Size = New-Object System.Drawing.Size(350,50)
    $connect_button.Location = New-Object System.Drawing.Point((400-175),(400-15))
    $connect_button.Text = "Connect to Azure AD"
    $connect_button.Font = New-Object System.Drawing.Font("Lucida Console",20,[System.Drawing.FontStyle]::Regular)

    # Button press function
    $connect_button_click = {
        try {
            Connect-AzureAD -ErrorAction Ignore
            $connection = Get-AzureADCurrentSessionInfo -ErrorAction Ignore
        } catch {
            $connection = $null
        }
        if ($connection -ne $null) {
            $main.Controls.Remove($connect_button)
            $main.Text = "Azure Ad Control Tool: $($connection.Account.Id.ToString())"
        }
    }

    $connect_button.Add_Click($connect_button_click)
    $main.Controls.Add($connect_button)
} else {
    $main.Text = "Azure Ad Control Tool: $($connection.Account.Id.ToString())"

    $userlist = Get-AzureADUser -All $true | where {$_.UserPrincipalName -notlike '*Sync_*' -and $_.UserPrincipalName -notlike '*Admin*'}

    $listbox = New-Object System.Windows.Forms.ListView
    $listbox.Location = New-Object System.Drawing.Point(100,100)
    $listbox.Size = New-Object System.Drawing.Size(600,350)
    $listbox.Name = "List of Azure AD Users"
    $listbox.CheckBoxes = $false
    $listbox.GridLines = $true
    $listbox.Sorting = 1
    $listbox.View = 1
    $listbox.FullRowSelect = $true

    $displayColumn = $listbox.Columns.Add('DisplayName')
    $displayColumn.Width = 200
    $principalColumn = $listbox.Columns.Add('PrincipalName')
    $principalColumn.Width = 300

    foreach($user in $userlist) {
        $item1 = New-Object System.Windows.Forms.ListViewItem($user.DisplayName.ToString())
        $item1.SubItems.Add($user.UserPrincipalName.ToString())
        $listbox.Items.Add($item1)
    }

    $main.Controls.Add($listbox)
}


$main.ShowDialog()

# Disconnect Azure Ad connection on close
#if ($connection -ne $null -and [System.Windows.Forms.DialogResult]::Cancel) {
#    Disconnect-AzureAD
#}