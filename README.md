# Quick Scripts

A simple CLI menu for storing and quickly running commonly used Windows PowerShell commands or scripts.

## Setup

1. Add this to your PowerShell profile ($PROFILE):

```powershell

function qs {
    # 1. Add a newline so the TUI starts on its own row
    Write-Host "" 

    # 2. Run the script and capture choice
    $choice = & "C:\Users\Caleb.Walls\Personal-Development\PS-Quick-Command\QuickScript.ps1"
    
    # 3. Execute the selected script / command
    if ($choice) {
        [System.Windows.Forms.SendKeys]::SendWait("$choice{ENTER}")
    }
}

```

2. Reload your profile: `. $PROFILE`

3. Run `qs` to launch the menu

## Configuration

Commands are stored in `$HOME\.quick_scripts.json`, which gets updated as you use the tool.