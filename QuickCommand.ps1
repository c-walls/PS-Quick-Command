# --- Configuration ---
$dbPath = "$HOME\.quick_commands.json"
$ESC = [char]27
$CLEAR_LINE = "$ESC[2K"

# Initialize JSON if not exists
if (-not (Test-Path $dbPath)) {
    $initial = @(
        @{ id = "1"; cmd = "git status" }
        @{ id = "2"; cmd = "echo 'Hello World'" }
    )
    $initial | ConvertTo-Json | Out-File $dbPath
}

# Load commands - handle single object case
$loaded = Get-Content $dbPath | ConvertFrom-Json
if ($loaded -is [Array]) {
    $script:commands = $loaded
} else {
    $script:commands = @($loaded)
}

function Draw-TUI {
    param([int]$selectedIndex)

    # Get 3/4 of window width
    $fullWidth = $Host.UI.RawUI.WindowSize.Width
    $width = [Math]::Floor($fullWidth * 0.75)
    $title = " Quick Commands "
    
    # Calculate padding for title
    $titleLength = $title.Length
    $totalLines = $width - $titleLength - 2  # -2 for corner characters
    $leftLines = [Math]::Floor($totalLines / 2)
    $rightLines = $totalLines - $leftLines
    
    # Top border ┌─ Quick Commands ─┐ (DarkCyan and bold)
    $horizontalLeft = ([char]0x2500).ToString() * $leftLines
    $horizontalRight = ([char]0x2500).ToString() * $rightLines
    $topBorder = [char]0x250C + $horizontalLeft
    Write-Host $topBorder -NoNewline -ForegroundColor DarkGray
    # Title with bold ANSI code and DarkCyan
    Write-Host "$ESC[1m$title$ESC[0m" -NoNewline -ForegroundColor DarkCyan
    Write-Host ($horizontalRight + [char]0x2510) -ForegroundColor DarkGray
    
    # Commands with side borders
    $contentWidth = $width - 4  # Account for "│ " and " │"
    for ($i = 0; $i -lt $script:commands.Count; $i++) {
        $num = $i + 1
        $text = " $num. $($script:commands[$i].cmd) "
        if ($i -eq $selectedIndex) {
            Write-Host ([char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Black -BackgroundColor Cyan
            Write-Host (" " + [char]0x2502) -ForegroundColor DarkGray
        } else {
            Write-Host ([char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
            Write-Host $text.PadRight($contentWidth) -NoNewline -ForegroundColor Gray
            Write-Host (" " + [char]0x2502) -ForegroundColor DarkGray
        }
    }
    
    # Bottom border └────┘
    $horizontal = ([char]0x2500).ToString() * ($width - 2)
    $bottomBorder = [char]0x2514 + $horizontal + [char]0x2518
    Write-Host $bottomBorder -ForegroundColor DarkGray
    
    # Instructions BELOW the box (centered)
    $instructionsText = "[Enter] Execute  [A] Add Last  [Ctrl+D] Delete  [Esc] Cancel"
    $instructionsLength = $instructionsText.Length
    $leftPadding = [Math]::Floor(($width - $instructionsLength) / 2)
    $rightPadding = $width - $instructionsLength - $leftPadding
    $instructions = (" " * $leftPadding) + $instructionsText + (" " * $rightPadding)
    Write-Host $instructions -ForegroundColor DarkGray
    
    # CLI preview with selected command
    $prompt = "PS > "
    $selectedCmd = $script:commands[$selectedIndex].cmd
    Write-Host $prompt -NoNewline -ForegroundColor Green
    Write-Host $selectedCmd -ForegroundColor White
}

function Show-QuickCommands {
    $selectedIndex = 0
    Write-Host "$ESC[?25l" -NoNewline
    
    while ($true) {
        $linesToClear = $script:commands.Count + 4  # top + commands + instructions + bottom + cli
        Draw-TUI -selectedIndex $selectedIndex
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        for ($i = 0; $i -lt $linesToClear; $i++) {
            Write-Host "$ESC[1A$CLEAR_LINE" -NoNewline
        }

        # Check for Ctrl+D
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
            }
            continue
        }

        switch ($key.VirtualKeyCode) {
            38 { $selectedIndex = [Math]::Max(0, $selectedIndex - 1) }
            40 { $selectedIndex = [Math]::Min($script:commands.Count - 1, $selectedIndex + 1) }
            13 {
                Write-Host "$ESC[1A$CLEAR_LINE" -NoNewline
                Write-Host "$ESC[?25h" -NoNewline
                return $script:commands[$selectedIndex].cmd
            }
            27 {
                Write-Host "$ESC[1A$CLEAR_LINE" -NoNewline
                Write-Host "$ESC[?25h" -NoNewline
                return $null
            }
            65 {
                $history = Get-History -Count 5 | Where-Object { $_.CommandLine -notmatch "QuickCommand|qc" } | Select-Object -Last 1
                if ($history) {
                    $last = $history.CommandLine
                    $exists = $script:commands | Where-Object { $_.cmd -eq $last }
                    if (-not $exists) {
                        $newId = ($script:commands.Count + 1).ToString()
                        $script:commands += [PSCustomObject]@{ id = $newId; cmd = $last }
                        $script:commands | ConvertTo-Json | Out-File $dbPath
                    }
                }
            }
            default {
                if ($key.Character -match '^[1-9]$') {
                    $num = [int]$key.Character - 1
                    if ($num -lt $script:commands.Count) { $selectedIndex = $num }
                }
            }
        }
    }
}

# --- Execution ---
return Show-QuickCommands