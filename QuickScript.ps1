# --- Configuration ---
$dbPath = "$PSScriptRoot\.quick_scripts.json"
$maxWidth = 80
$alias = "qs"

# UI Constants
$ESC = [char]27
$CLEAR_TO_END = "$ESC[J"
$CLEAR_LINE = "$ESC[K"
$BOLD_ON = "$ESC[1m"
$BOLD_OFF = "$ESC[0m"
$Title = " Quick Scripts "
$InstructionsText = "[ALT] Toggle Keymap"

# Box drawing characters
$BOX_TL = [char]0x250C  # ┌
$BOX_TR = [char]0x2510  # ┐
$BOX_BL = [char]0x2514  # └
$BOX_BR = [char]0x2518  # ┘
$BOX_H  = [char]0x2500  # ─
$BOX_V  = [char]0x2502  # │
$ARROW_UP = [char]0x2191    # ↑
$ARROW_DOWN = [char]0x2193  # ↓

$UI_TOP_MARKER = "###TOP###"
$UI_CLI_MARKER = "###CLI###"

$script:keymaps = @(
    @{ key = "[Esc]"; name = "Close Menu" }
    @{ key = "[$ARROW_UP/$ARROW_DOWN]"; name = "Navigate Menu" }
    @{ key = "[Enter]"; name = "Run Command" }
    @{ key = "[Ctrl+Enter]"; name = "Modify Then Run Command" }
    @{ key = "[Ctrl+R]"; name = "Rename Command" }
    @{ key = "[Ctrl+D]"; name = "Delete Command" }
    @{ key = "[A]"; name = "Add Last Command" }
)

# Initialize JSON if not exists
if (-not (Test-Path $dbPath)) {
    $initial = @(
        @{ name = "View Scripts JSON"; cmd = "Get-Content $dbPath -Raw" }
        @{ name = "Example Script"; cmd = "echo 'Example'" }
    )
    $initial | ConvertTo-Json | Out-File $dbPath
}

# Load commands
$loaded = Get-Content $dbPath | ConvertFrom-Json
$script:commands = @($loaded)


function Save-Commands {
    $script:commands | ConvertTo-Json | Out-File $dbPath
}

function Close-QuickScriptsMenu {
    param([bool]$cursorVisible)

    [Console]::CursorVisible = $cursorVisible
    Clear-MenuRegion
}

function Test-CtrlPressed {
    param($key)

    return $key.ControlKeyState -match "LeftCtrlPressed|RightCtrlPressed"
}

# Find the last row whose rendered text starts with a sentinel marker.
function Find-LastSentinelRow {
    param([string]$Sentinel)

    $rawUI = $Host.UI.RawUI
    $bufferWidth = [int]$rawUI.BufferSize.Width
    $currentY = [int]$rawUI.CursorPosition.Y

    if ($bufferWidth -le 0) {
        return $null
    }

    # Search BACKWARD from current cursor position (find most recent marker)
    for ($row = $currentY; $row -ge [Math]::Max(0, $currentY - 100); $row--) {
        try {
            $left = 0
            $top = $row
            $right = $bufferWidth - 1
            $bottom = $row
            
            $rect = New-Object System.Management.Automation.Host.Rectangle($left, $top, $right, $bottom)
            $cells = $rawUI.GetBufferContents($rect)

            if (-not $cells) {
                continue
            }

            # Build the line string
            $chars = @()
            for ($col = 0; $col -lt $bufferWidth; $col++) {
                $chars += $cells[0, $col].Character
            }
            $line = -join $chars
            
            if ($line.StartsWith($Sentinel)) {
                return $row
            }
        } catch {
            continue
        }
    }

    return $null
}

# Clears from the latest UI marker row to the bottom of terminal.
function Clear-MenuRegion {
    $rawUI = $Host.UI.RawUI
    $topRow = Find-LastSentinelRow -Sentinel $UI_TOP_MARKER
    if ($null -eq $topRow) { return}

    $rawUI.CursorPosition = @{ X = 0; Y = $topRow }  
    Write-Host $CLEAR_TO_END -NoNewline
}

function Draw-TUI {
    param(
        [int]$selectedIndex,
        [bool]$keymapVisible = $false
    )

    $rawUI = $Host.UI.RawUI
    $width = [Math]::Min($maxWidth, $rawUI.WindowSize.Width - 4)
    $contentWidth = $width - 4

    # Hidden top anchor for redraw/clear operations.
    Write-Host $UI_TOP_MARKER -ForegroundColor Black -BackgroundColor Black
    
    # --- Top border ---
    $titleLength = $Title.Length
    $leftLines = [Math]::Floor(($width - $titleLength - 2) / 2)
    $rightLines = $width - $titleLength - 2 - $leftLines
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
        $isKeymap = $keymapVisible
        $maxNameLength = $contentWidth - 5

        if ($isKeymap) {
            $keyPart = $displayName.key
            $namePart = $displayName.name
            $fullText = "$keyPart $namePart"
        } else {
            if ($displayName.Length -gt $maxNameLength -and $maxNameLength -gt 3) {
                $displayName = $displayName.Substring(0, $maxNameLength - 3) + "..."
            }
            $fullText = " $displayName "
        }

        $text = if ($isKeymap) { " $fullText " } else { $fullText }
        $isSelected = (-not $keymapVisible -and $i -eq $selectedIndex)

        Write-Host "$BOX_V " -NoNewline -ForegroundColor DarkGray
        if ($isSelected) {
            Write-Host "$BOLD_ON$($text.PadRight($contentWidth))$BOLD_OFF" -NoNewline -ForegroundColor White -BackgroundColor DarkCyan
        } elseif ($isKeymap) {
            Write-Host " " -NoNewline
            Write-Host $keyPart -NoNewline -ForegroundColor Green
            Write-Host " $namePart".PadRight($contentWidth - $keyPart.Length - 1) -NoNewline -ForegroundColor Gray
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
    
    # Hidden CLI anchor so prompt-relative operations remain stable.
    Write-Host $UI_CLI_MARKER -ForegroundColor Black -BackgroundColor Black

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

function Get-ModifyInput {
    param([string]$currentCmd)

    $rawUI = $Host.UI.RawUI

    # Move cursor to PS > line
    $cursorPos = $rawUI.CursorPosition
    $cursorPos.Y -= 1
    $cursorPos.X = 0
    $rawUI.CursorPosition = $cursorPos

    [Console]::CursorVisible = $true

    $input = $currentCmd
    $cursorIndex = $input.Length

    while ($true) {

        # Redraw entire region (safe for wrapped lines)
        $rawUI.CursorPosition = $cursorPos
        Write-Host $CLEAR_TO_END -NoNewline
        $rawUI.CursorPosition = $cursorPos

        Write-Host "PS > " -NoNewline -ForegroundColor Green
        Write-Host "Press [Enter] After Modifying: " -NoNewline -ForegroundColor Yellow
        Write-Host $input -NoNewline -ForegroundColor White

        # Reposition cursor visually
        $prefixLength = ("PS > " + "Press [Enter] After Modifying: ").Length
        $absoluteIndex = $prefixLength + $cursorIndex

        $newX = $absoluteIndex % $rawUI.BufferSize.Width
        $newY = $cursorPos.Y + [Math]::Floor($absoluteIndex / $rawUI.BufferSize.Width)

        $rawUI.CursorPosition = @{ X = $newX; Y = $newY }

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
                if ($cursorIndex -gt 0) {
                    $input = $input.Remove($cursorIndex - 1, 1)
                    $cursorIndex--
                }
            }

            37 { # Left arrow
                if ($cursorIndex -gt 0) {
                    $cursorIndex--
                }
            }

            39 { # Right arrow
                if ($cursorIndex -lt $input.Length) {
                    $cursorIndex++
                }
            }

            default {
                if ($key.Character -and -not [char]::IsControl($key.Character)) {
                    $input = $input.Insert($cursorIndex, $key.Character)
                    $cursorIndex++
                }
            }
        }
    }
}

function Show-QuickScripts {

    $rawUI = $Host.UI.RawUI
    $script:keymapVisible = $false
    $script:selectedIndex = 0

    # Hide cursor while menu is active
    $originalCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    Draw-TUI -selectedIndex $script:selectedIndex -keymapVisible $script:keymapVisible

    while ($true) {

        $key = $rawUI.ReadKey("NoEcho,IncludeKeyDown")
        $needsRedraw = $false

        # Toggle keymap visibility with ALT
        if ($key.VirtualKeyCode -in @(18, 164, 165)) {
            $script:keymapVisible = -not $script:keymapVisible
            $needsRedraw = $true
        }
        
        # Only the ESC key works if keymap is visble.
        elseif ($script:keymapVisible) {
            if ($key.VirtualKeyCode -eq 27) {
                Close-QuickScriptsMenu -cursorVisible $originalCursorVisible
                return $null
            }
        }

        # Handle Ctrl+D - Delete
        elseif (($key.VirtualKeyCode -eq 68 -and (Test-CtrlPressed -key $key)) -or ($key.Character -eq [char]4)) {
            if ($script:commands.Count -gt 1) {
                $script:commands = @($script:commands | Where-Object { $_ -ne $script:commands[$script:selectedIndex] })
                Save-Commands
                if ($script:selectedIndex -ge $script:commands.Count) {
                    $script:selectedIndex = $script:commands.Count - 1
                }
                $needsRedraw = $true
            }
        }

        # Handle Ctrl+R - Rename
        elseif ($key.VirtualKeyCode -eq 82 -and (Test-CtrlPressed -key $key)) {
            $newName = Get-RenameInput -currentName $script:commands[$script:selectedIndex].name -currentCmd $script:commands[$script:selectedIndex].cmd
            if ($newName -and $newName -ne $script:commands[$script:selectedIndex].name) {
                # Check for duplicate names
                $duplicate = $script:commands | Where-Object { $_.name -eq $newName -and $_ -ne $script:commands[$script:selectedIndex] }
                if (-not $duplicate) {
                    $script:commands[$script:selectedIndex].name = $newName
                    Save-Commands
                }
            }
            $needsRedraw = $true
        }

        # Handle Ctrl+Enter - Modify Then Run
        elseif ($key.VirtualKeyCode -eq 13 -and (Test-CtrlPressed -key $key)) {
            $modified = Get-ModifyInput -currentCmd $script:commands[$script:selectedIndex].cmd
            if ($modified) {
                Close-QuickScriptsMenu -cursorVisible $originalCursorVisible
                return $modified
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
                    Close-QuickScriptsMenu -cursorVisible $originalCursorVisible
                    return $script:commands[$script:selectedIndex].cmd
                }

                27 { # Escape
                    Close-QuickScriptsMenu -cursorVisible $originalCursorVisible
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
                            Save-Commands
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
            Clear-MenuRegion
            Draw-TUI -selectedIndex $script:selectedIndex -keymapVisible $script:keymapVisible
        }
    }
}

# --- Execution ---
return Show-QuickScripts
