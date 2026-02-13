# --- Configuration ---
$dbPath = "$HOME\.quick_scripts.json"
$alias = "qs"

# UI Constants
$ESC = [char]27
$CLEAR_TO_END = "$ESC[J"
$CLEAR_LINE = "$ESC[K"
$BOLD_ON = "$ESC[1m"
$BOLD_OFF = "$ESC[0m"
$Title = " Quick Scripts "
$InstructionsText = "Toggle Keymap [SHIFT]"

$script:keymaps = @(
    "[Shift] Toggle keymap"
    "[Up/Down] Navigate"
    "[Enter] Execute"
    "[A] Add"
    "[Ctrl+D] Delete"
    "[Ctrl+R] Rename"
    "[1-9] Jump to item"
    "[Esc] Cancel"
)

# Box drawing characters
$BOX_TL = [char]0x250C  # ┌
$BOX_TR = [char]0x2510  # ┐
$BOX_BL = [char]0x2514  # └
$BOX_BR = [char]0x2518  # ┘
$BOX_H  = [char]0x2500  # ─
$BOX_V  = [char]0x2502  # │

# Initialize JSON if not exists
if (-not (Test-Path $dbPath)) {
    $initial = @(
        @{ name = "View Scripts"; cmd = "Get-Content `$HOME\.quick_scripts.json -Raw" }
        @{ name = "Example"; cmd = "echo 'Example'" }
    )
    $initial | ConvertTo-Json | Out-File $dbPath
}

# Load commands
$loaded = Get-Content $dbPath | ConvertFrom-Json
$script:commands = @($loaded)

# Clears from the start row to the bottom of terminal (handles window resizing)
function Clear-MenuRegion {
    $rawUI = $Host.UI.RawUI
    $rawUI.CursorPosition = @{ X = 0; Y = $script:StartRow }    
    Write-Host $CLEAR_TO_END -NoNewline
}

function Draw-TUI {
    param(
        [int]$selectedIndex,
        [bool]$keymapVisible = $false
    )

    $rawUI = $Host.UI.RawUI
    $fullWidth = $rawUI.WindowSize.Width

    # Minimum required width is instruction text + frame padding
    $minWidth = $InstructionsText.Length + 4
    $width = [Math]::Min(100, $fullWidth - 4)
    $contentWidth = $width - 4

    # --- Top border ---
    $titleLength = $Title.Length
    $leftLines = [Math]::Floor(($width - $titleLength - 2) / 2)
    $rightLines = $width - $titleLength - 2 - $leftLines

    Write-Host ""
    Write-Host ($BOX_TL + ($BOX_H.ToString() * $leftLines)) -NoNewline -ForegroundColor DarkGray
    Write-Host "$BOLD_ON$Title$BOLD_OFF" -NoNewline -ForegroundColor DarkBlue
    Write-Host (($BOX_H.ToString() * $rightLines) + $BOX_TR) -ForegroundColor DarkGray

    $rows = if ($keymapVisible) {
        $script:keymaps
    } else {
        for ($i = 0; $i -lt $script:commands.Count; $i++) {
            "$($i + 1). $($script:commands[$i].name)"
        }
    }

    # --- List ---
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $displayName = $rows[$i]

        # Truncate long names with "..." for display only
        $maxNameLength = $contentWidth - 5
        if ($displayName.Length -gt $maxNameLength -and $maxNameLength -gt 3) {
            $displayName = $displayName.Substring(0, $maxNameLength - 3) + "..."
        }

        $text = " $displayName "
        $isSelected = (-not $keymapVisible -and $i -eq $selectedIndex)

        Write-Host "$BOX_V " -NoNewline -ForegroundColor DarkGray
        if ($isSelected) {
            Write-Host "$BOLD_ON$($text.PadRight($contentWidth))$BOLD_OFF" -NoNewline -ForegroundColor White -BackgroundColor DarkCyan
        } else {
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Gray
        }
        Write-Host " $BOX_V" -ForegroundColor DarkGray
    }

    # --- Bottom border ---
    Write-Host ($BOX_BL + ($BOX_H.ToString() * ($width - 2)) + $BOX_BR) -ForegroundColor DarkGray

    # --- Instructions ---
    $leftPadding = [Math]::Floor(($width - $InstructionsText.Length) / 2)
    Write-Host (" " * [Math]::Max(0, $leftPadding) + $InstructionsText) -ForegroundColor DarkGray
    Write-Host ""

    # --- CLI preview ---
    Write-Host "PS > " -NoNewline -ForegroundColor Green
    if ($keymapVisible) {
        Write-Host ""
    } else {
        Write-Host $script:commands[$selectedIndex].cmd -ForegroundColor White
    }
}

function Get-RenameInput {
    param([string]$currentName, [string]$currentCmd)
    
    $maxLength = 60
    $rawUI = $Host.UI.RawUI
    
    # Move cursor to the PS > line (up 1 from current position)
    $cursorPos = $rawUI.CursorPosition
    $cursorPos.Y -= 1
    $cursorPos.X = 0
    $rawUI.CursorPosition = $cursorPos
    
    # Clear the line and show cursor
    Write-Host $CLEAR_LINE -NoNewline
    $rawUI.CursorPosition = $cursorPos
    [Console]::CursorVisible = $true
    
    # Start with current name, or empty if it matches command OR exceeds limit
    $input = if ($currentName -eq $currentCmd -or $currentName.Length -gt $maxLength) { 
        "" 
    } else { 
        $currentName 
    }
    
    while ($true) {
        # Redraw input line
        $rawUI.CursorPosition = $cursorPos
        Write-Host $CLEAR_LINE -NoNewline
        $rawUI.CursorPosition = $cursorPos
        Write-Host "PS > " -NoNewline -ForegroundColor Green
        Write-Host "name: " -NoNewline -ForegroundColor Yellow
        Write-Host $input -NoNewline -ForegroundColor White
        
        $key = $rawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            13 { # Enter
                [Console]::CursorVisible = $false
                return $input.Trim()
            }
            27 { # Escape
                [Console]::CursorVisible = $false
                return $null
            }
            8 { # Backspace
                if ($input.Length -gt 0) {
                    $input = $input.Substring(0, $input.Length - 1)
                }
            }
            default {
                # Only accept printable characters if under max length
                if ($key.Character -and -not [char]::IsControl($key.Character) -and $input.Length -lt $maxLength) {
                    $input += $key.Character
                }
            }
        }
    }
}

function Show-QuickScripts {

    $script:selectedIndex = 0
    $script:keymapVisible = $false
    $rawUI = $Host.UI.RawUI

    # Hide cursor while menu is active
    $originalCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    # Capture starting cursor row
    $script:StartRow = $rawUI.CursorPosition.Y

    $minWidth = $InstructionsText.Length + 4
    $fullWidth = $rawUI.WindowSize.Width
    if ($fullWidth -lt $minWidth) {
        return "Window too small. Resize to at least $minWidth columns."
    }

    Draw-TUI -selectedIndex $script:selectedIndex -keymapVisible $script:keymapVisible

    while ($true) {

        $key = $rawUI.ReadKey("NoEcho,IncludeKeyDown")
        $needsRedraw = $false

        if ($key.VirtualKeyCode -in @(16, 160, 161)) {
            $script:keymapVisible = -not $script:keymapVisible
            $needsRedraw = $true
        }
        elseif ($script:keymapVisible) {
            # POC behavior: when keymap is visible, only SHIFT toggling is active.
        }

        # Handle Ctrl+D - Delete
        elseif (($key.VirtualKeyCode -eq 68 -and $key.ControlKeyState -match "LeftCtrlPressed|RightCtrlPressed") -or ($key.Character -eq [char]4)) {
            if ($script:commands.Count -gt 1) {
                $script:commands = @($script:commands | Where-Object { $_ -ne $script:commands[$script:selectedIndex] })
                $script:commands | ConvertTo-Json | Out-File $dbPath
                # Adjust selection if needed
                if ($script:selectedIndex -ge $script:commands.Count) {
                    $script:selectedIndex = $script:commands.Count - 1
                }
                $needsRedraw = $true
            }
        }
        # Handle Ctrl+R - Rename
        elseif ($key.VirtualKeyCode -eq 82 -and $key.ControlKeyState -match "LeftCtrlPressed|RightCtrlPressed") {
            $newName = Get-RenameInput -currentName $script:commands[$script:selectedIndex].name -currentCmd $script:commands[$script:selectedIndex].cmd
            if ($newName -and $newName -ne $script:commands[$script:selectedIndex].name) {
                # Check for duplicate names
                $duplicate = $script:commands | Where-Object { $_.name -eq $newName -and $_ -ne $script:commands[$script:selectedIndex] }
                if (-not $duplicate) {
                    $script:commands[$script:selectedIndex].name = $newName
                    $script:commands | ConvertTo-Json | Out-File $dbPath
                }
            }
            $needsRedraw = $true
        }
        else {
            # Handle other keys
            switch ($key.VirtualKeyCode) {

                38 { # Up
                    $script:selectedIndex = [Math]::Max(0, $script:selectedIndex - 1)
                    $needsRedraw = $true
                }

                40 { # Down
                    $script:selectedIndex = [Math]::Min($script:commands.Count - 1, $script:selectedIndex + 1)
                    $needsRedraw = $true
                }

                13 { # Enter
                    [Console]::CursorVisible = $originalCursorVisible
                    Clear-MenuRegion
                    return $script:commands[$script:selectedIndex].cmd
                }

                27 { # Escape
                    [Console]::CursorVisible = $originalCursorVisible
                    Clear-MenuRegion
                    return $null
                }

                65 { # A - Add last command from history
                    $history = Get-History -Count 5 | Where-Object { $_.CommandLine -notmatch $alias } | Select-Object -Last 1
                    if ($history) {
                        $cmdToAdd = $history.CommandLine
                        # Check for duplicates
                        $duplicate = $script:commands | Where-Object { $_.cmd -eq $cmdToAdd }
                        if (-not $duplicate) {
                            $newCommand = [PSCustomObject]@{ 
                                name = $cmdToAdd
                                cmd = $cmdToAdd
                            }
                            $script:commands = @($script:commands) + @($newCommand)
                            $script:commands | ConvertTo-Json | Out-File $dbPath
                            $needsRedraw = $true
                        }
                    }
                }

                default {
                    # Number keys 1-9 for quick selection
                    if ($key.Character -match '^[1-9]$') {
                        $num = [int]::Parse($key.Character) - 1
                        if ($num -lt $script:commands.Count) {
                            $script:selectedIndex = $num
                            $needsRedraw = $true
                        }
                    }
                }
            }
        }

        if ($needsRedraw) {
            $fullWidth = $rawUI.WindowSize.Width
            if ($fullWidth -lt $minWidth) {
                [Console]::CursorVisible = $originalCursorVisible
                Clear-MenuRegion
                return "Window too small. Resize to at least $minWidth columns."
            }
            Clear-MenuRegion
            Draw-TUI -selectedIndex $script:selectedIndex -keymapVisible $script:keymapVisible
        }
    }
}

# --- Execution ---
return Show-QuickScripts
