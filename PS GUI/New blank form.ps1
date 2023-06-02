# Load .NET framework classes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create a new blank form/window
$main = New-Object System.Windows.Forms.Form
$main.Text = 'New Form'
$main.Size = New-Object System.Drawing.Size(300,200)
$main.StartPosition = 'CenterScreen'

$main.TopMost = $true
$main.ShowDialog()