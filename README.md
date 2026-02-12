# Quick Command

A simple CLI menu for storing and quickly running commonly used Windows PowerShell commands.

## Setup

1. Add this to your PowerShell profile ($PROFILE):

```powershell
function qc {
    # 1. Add a newline so the TUI starts on its own row
    Write-Host "" 

    # 2. Run the script and capture choice
    $choice = & "C:\Users\Caleb.Walls\Personal-Development\PS-Quick-Command\QuickCommand.ps1"
    
    # 3. Use the SAME variable name ($choice) here
    if ($choice) {
        # Flush any leftover keypresses
        #while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
        
        # This "types" the command and hits Enter for you
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait("$choice{ENTER}")
    }
}
```

2. Reload your profile: `. $PROFILE`

3. Run `qc` to launch the menu

## Configuration

Commands are stored in `~/.quickcommand/config.json` - edit this file to customize your commands.