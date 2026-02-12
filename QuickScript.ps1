# --- Configuration ---
$dbPath = "$HOME\.quick_scripts.json"
$alias = "qs"

# UI Constants
$Title = " Quick Scripts "
$InstructionsText = "[Enter] Execute  [A] Add  [Ctrl+D] Delete  [Ctrl+R] Rename  [Esc] Cancel"

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
        @{ id = "1"; name = "View Scripts"; cmd = "Get-Content `$HOME\.quick_scripts.json -Raw" }
        @{ id = "2"; name = "Example"; cmd = "echo 'Example'" }
    )
    $initial | ConvertTo-Json | Out-File $dbPath
}

# Load commands
$loaded = Get-Content $dbPath | ConvertFrom-Json
$script:commands = @($loaded)

# Clears only the region occupied by the menu (preserves terminal history)
function Clear-MenuRegion {
    param([int]$lineCount)

    $rawUI = $Host.UI.RawUI
    $rawUI.CursorPosition = @{ X = 0; Y = $script:StartRow }

    for ($i = 0; $i -lt $lineCount; $i++) {
        Write-Host (" " * $rawUI.WindowSize.Width)
    }

    $rawUI.CursorPosition = @{ X = 0; Y = $script:StartRow }
}

function Draw-TUI {
    param([int]$selectedIndex)

    $rawUI = $Host.UI.RawUI
    $fullWidth = $rawUI.WindowSize.Width

    # Use instruction length as minimum required width
    $minWidth = $InstructionsText.Length + 4

    if ($fullWidth -lt $minWidth) {
        Write-Host ""
        Write-Host "  Window too small." -ForegroundColor Red
        Write-Host "  Resize to at least $minWidth columns." -ForegroundColor DarkGray
        $script:LastRenderHeight = 3
        return
    }

    $width = [Math]::Min(100, $fullWidth - 4)
    $contentWidth = $width - 4
    $renderedLines = 0

    # --- Top border ---
    $titleLength = $Title.Length
    $leftLines = [Math]::Floor(($width - $titleLength - 2) / 2)
    $rightLines = $width - $titleLength - 2 - $leftLines

    Write-Host ($BOX_TL + ($BOX_H.ToString() * $leftLines)) -NoNewline -ForegroundColor DarkGray
    Write-Host $Title -NoNewline -ForegroundColor DarkCyan
    Write-Host (($BOX_H.ToString() * $rightLines) + $BOX_TR) -ForegroundColor DarkGray
    $renderedLines++

    # --- Scripts ---
    for ($i = 0; $i -lt $script:commands.Count; $i++) {
        $num = $i + 1
        $displayName = $script:commands[$i].name

        # Truncate long names with "..." for display only
        $maxNameLength = $contentWidth - 5
        if ($displayName.Length -gt $maxNameLength -and $maxNameLength -gt 3) {
            $displayName = $displayName.Substring(0, $maxNameLength - 3) + "..."
        }

        $text = " $num. $displayName "
        $isSelected = ($i -eq $selectedIndex)

        Write-Host "$BOX_V " -NoNewline -ForegroundColor DarkGray
        if ($isSelected) {
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Black -BackgroundColor Cyan
        } else {
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Gray
        }
        Write-Host " $BOX_V" -ForegroundColor DarkGray
        $renderedLines++
    }

    # --- Bottom border ---
    Write-Host ($BOX_BL + ($BOX_H.ToString() * ($width - 2)) + $BOX_BR) -ForegroundColor DarkGray
    $renderedLines++

    # --- Instructions ---
    $leftPadding = [Math]::Floor(($width - $InstructionsText.Length) / 2)
    Write-Host (" " * $leftPadding + $InstructionsText) -ForegroundColor DarkGray
    $renderedLines++

    Write-Host ""
    $renderedLines++

    # --- CLI preview ---
    Write-Host "PS > " -NoNewline -ForegroundColor Green
    Write-Host $script:commands[$selectedIndex].cmd -ForegroundColor White
    $renderedLines++

    # Store how many lines we rendered so we can clear exactly this region later
    $script:LastRenderHeight = $renderedLines
}

function Show-QuickScripts {

    $script:selectedIndex = 0

    # Capture starting cursor row so we only redraw our own region
    $script:StartRow = $Host.UI.RawUI.CursorPosition.Y

    Draw-TUI -selectedIndex $script:selectedIndex

    while ($true) {

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $needsRedraw = $false

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
                Clear-MenuRegion $script:LastRenderHeight
                return $script:commands[$script:selectedIndex].cmd
            }

            27 { # Escape
                Clear-MenuRegion $script:LastRenderHeight
                return $null
            }
        }

        if ($needsRedraw) {
            Clear-MenuRegion $script:LastRenderHeight
            Draw-TUI -selectedIndex $script:selectedIndex
        }
    }
}

# --- Execution ---
return Show-QuickScripts
