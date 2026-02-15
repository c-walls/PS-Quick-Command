# Quick Scripts

A simple CLI menu for storing and quickly running commonly used Windows PowerShell commands or scripts.

## Setup

1. Add this to your PowerShell profile ($PROFILE):

```powershell

function qs {
    # Run the script and capture choice
    $choice = & "C:\Users\Caleb.Walls\Personal-Development\PS-Quick-Scripts\QuickScript.ps1"
    
    # Execute the selected command / script
    if ($choice) {
	    Write-Host "PS $PWD> " -NoNewline -ForegroundColor Green
        Write-Host $choice -ForegroundColor Gray
        Invoke-Expression $choice
    }
}


```

2. Reload your profile: `. $PROFILE`

3. Run `qs` to launch the menu

## Configuration

Commands are stored in `.\.quick_scripts.json` in the repo folder.