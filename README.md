# Quick Scripts

A simple CLI menu for storing and quickly running commonly used Windows PowerShell commands or scripts.

## Setup

1. Add this to your PowerShell profile ($PROFILE):

```powershell

function qs {
    # Run the script and capture choice
    # Note: Update the path below to point to your local PS-Quick-Scripts folder
    $choice = & "C:\path\to\PS-Quick-Scripts\QuickScript.ps1"
    
    # Execute the selected command / script
    if ($choice) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait("$choice{ENTER}")
    }
}



```

2. Reload your profile: `. $PROFILE`

3. Run `qs` to launch the menu

## Configuration

Commands are stored in `.\.quick_scripts.json` in the repo folder.