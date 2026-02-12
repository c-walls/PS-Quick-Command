# --- Configuration ---
$dbPath = "$HOME\.quick_commands.json"
$ESC = [char]27
$CLEAR_LINE = "$ESC[2K"

# Box drawing characters
$BOX_TL = [char]0x250C  # ┌
$BOX_TR = [char]0x2510  # ┐
$BOX_BL = [char]0x2514  # └
$BOX_BR = [char]0x2518  # ┘
$BOX_H = [char]0x2500   # ─
$BOX_V = [char]0x2502   # │

# Initialize JSON if not exists
if (-not (Test-Path $dbPath)) {
    $initial = @(
        @{ id = "1"; cmd = "Get-Content $HOME\.quick_commands.json -Raw" }
        @{ id = "2"; cmd = "echo 'Example'" }
    )
    $initial | ConvertTo-Json | Out-File $dbPath
}

# Load commands - handle single object case
$loaded = Get-Content $dbPath | ConvertFrom-Json
$script:commands = if ($loaded -is [Array]) { $loaded } else { @($loaded) }

function Draw-TUI {
    param([int]$selectedIndex)

    $fullWidth = $Host.UI.RawUI.WindowSize.Width
    $width = [Math]::Floor($fullWidth * 0.75)
    $contentWidth = $width - 4
    $title = " Quick Commands "
    
    # Top border
    $titleLength = $title.Length
    $leftLines = [Math]::Floor(($width - $titleLength - 2) / 2)
    $rightLines = $width - $titleLength - 2 - $leftLines
    
    Write-Host ($BOX_TL + ($BOX_H.ToString() * $leftLines)) -NoNewline -ForegroundColor DarkGray
    Write-Host "$ESC[1m$title$ESC[0m" -NoNewline -ForegroundColor DarkCyan
    Write-Host (($BOX_H.ToString() * $rightLines) + $BOX_TR) -ForegroundColor DarkGray
    
    # Commands
    for ($i = 0; $i -lt $script:commands.Count; $i++) {
        $num = $i + 1
        $text = " $num. $($script:commands[$i].cmd) "
        $isSelected = ($i -eq $selectedIndex)
        
        Write-Host "$BOX_V " -NoNewline -ForegroundColor DarkGray
        if ($isSelected) {
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Black -BackgroundColor Cyan
        } else {
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Gray
        }
        Write-Host " $BOX_V" -ForegroundColor DarkGray
    }
    
    # Bottom border
    Write-Host ($BOX_BL + ($BOX_H.ToString() * ($width - 2)) + $BOX_BR) -ForegroundColor DarkGray
    
    # Instructions (centered) + gap
    $instructionsText = "[Enter] Execute  [A] Add Last  [Ctrl+D] Delete  [Esc] Cancel"
    $leftPadding = [Math]::Floor(($width - $instructionsText.Length) / 2)
    $rightPadding = $width - $instructionsText.Length - $leftPadding
    Write-Host ((" " * $leftPadding) + $instructionsText + (" " * $rightPadding)) -ForegroundColor DarkGray
    Write-Host ""
    
    # CLI preview
    Write-Host "PS > " -NoNewline -ForegroundColor Green
    Write-Host $script:commands[$selectedIndex].cmd -ForegroundColor White
}

function Clear-AndExit {
    param([int]$linesToClear, [string]$command)
    
    # Single string with all ANSI codes
    $clearSequence = (("$ESC[1A$CLEAR_LINE") * ($linesToClear + 1)) + "$ESC[?25h"
    Write-Host $clearSequence -NoNewline
    return $command
}

function Show-QuickCommands {
    $selectedIndex = 0
    Write-Host "$ESC[?25l" -NoNewline
    
    Draw-TUI -selectedIndex $selectedIndex
    
    while ($true) {
        $needsRedraw = $false
        $linesToClear = $script:commands.Count + 5
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Ctrl+D - Delete
        if (($key.VirtualKeyCode -eq 68 -and $key.ControlKeyState -match "LeftCtrlPressed|RightCtrlPressed") -or ($key.Character -eq [char]4)) {
            if ($script:commands.Count -gt 1) {
                $script:commands = @($script:commands | Where-Object { $_ -ne $script:commands[$selectedIndex] })
                for ($i = 0; $i -lt $script:commands.Count; $i++) {
                    $script:commands[$i].id = ($i + 1).ToString()
                }
                $script:commands | ConvertTo-Json | Out-File $dbPath
                if ($selectedIndex -ge $script:commands.Count) {
                    $selectedIndex = $script:commands.Count - 1
                }
                $needsRedraw = $true
            }
            continue
        }
        
        switch ($key.VirtualKeyCode) {
            38 { # Up
                $newIndex = [Math]::Max(0, $selectedIndex - 1)
                $needsRedraw = ($newIndex -ne $selectedIndex)
                $selectedIndex = $newIndex
            }
            40 { # Down
                $newIndex = [Math]::Min($script:commands.Count - 1, $selectedIndex + 1)
                $needsRedraw = ($newIndex -ne $selectedIndex)
                $selectedIndex = $newIndex
            }
            13 { return Clear-AndExit $linesToClear $script:commands[$selectedIndex].cmd } # Enter
            27 { return Clear-AndExit $linesToClear $null } # Escape
            65 { # A - Add
                $history = Get-History -Count 5 | Where-Object { $_.CommandLine -notmatch "QuickCommand|qc" } | Select-Object -Last 1
                if ($history -and -not ($script:commands | Where-Object { $_.cmd -eq $history.CommandLine })) {
                    $script:commands += [PSCustomObject]@{ id = ($script:commands.Count + 1).ToString(); cmd = $history.CommandLine }
                    $script:commands | ConvertTo-Json | Out-File $dbPath
                    $needsRedraw = $true
                }
            }
            default { # Number keys
                if ($key.Character -match '^[1-9]$') {
                    $num = [int]::Parse($key.Character) - 1
                    if ($num -lt $script:commands.Count -and $num -ne $selectedIndex) {
                        $selectedIndex = $num
                        $needsRedraw = $true
                    }
                }
            }
        }
        
        if ($needsRedraw) {
            for ($i = 0; $i -lt $linesToClear; $i++) {
                Write-Host "$ESC[1A$CLEAR_LINE" -NoNewline
            }
            Draw-TUI -selectedIndex $selectedIndex
        }
    }
}

# --- Execution ---
return Show-QuickCommands