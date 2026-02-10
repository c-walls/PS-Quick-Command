# --- Configuration ---
$dbPath = "$HOME\.quick_commands.json"
$ESC = [char]27
$CLEAR_LINE = "$ESC[2K"

# Initialize JSON if not exists
if (-not (Test-Path $dbPath)) {
    $initial = @(
        @{ id = "1"; cmd = "git status" },
        @{ id = "2"; cmd = "echo 'Hello World'" }
    )
    $initial | ConvertTo-Json | Out-File $dbPath
}

# Load commands
$commands = Get-Content $dbPath | ConvertFrom-Json

function Draw-TUI {
    param([int]$selectedIndex)

    Write-Host "--- Quick Commands -----------------------------" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $commands.Count; $i++) {
        $num = $i + 1
        $text = " $num. $($commands[$i].cmd) "
        if ($i -eq $selectedIndex) {
            Write-Host "| " -NoNewline -ForegroundColor DarkGray
            Write-Host $text.PadRight(48) -ForegroundColor Black -BackgroundColor Cyan -NoNewline
            Write-Host " |" -ForegroundColor DarkGray
        } else {
            Write-Host "| $($text.PadRight(48)) |" -ForegroundColor Gray
        }
    }
    Write-Host "------------------------------------------------" -ForegroundColor DarkGray
}

function Show-QuickCommands {
    $selectedIndex = 0
    Write-Host "$ESC[?25l" -NoNewline # Hide Cursor
    
    while ($true) {
        $linesToClear = $commands.Count + 2
        Draw-TUI -selectedIndex $selectedIndex
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        for ($i = 0; $i -lt $linesToClear; $i++) {
            Write-Host "$ESC[1A$CLEAR_LINE" -NoNewline
        }

        switch ($key.VirtualKeyCode) {
            38 { $selectedIndex = [Math]::Max(0, $selectedIndex - 1) } # Up
            40 { $selectedIndex = [Math]::Min($commands.Count - 1, $selectedIndex + 1) } # Down
            13 { Write-Host "$ESC[?25h" -NoNewline; return $commands[$selectedIndex].cmd } # Enter
            27 { Write-Host "$ESC[?25h" -NoNewline; return $null } # Escape

            65 { # 'A' Key -> Grab the last command, before QuickCommand was invoked, and add it to the QuickCommand list.
                $history = Get-History -Count 5 | Where-Object { $_.CommandLine -notmatch "QuickCommand" } | Select-Object -Last 1
                if ($history) {
                    $last = $history.CommandLine
                    $newId = ($commands.Count + 1).ToString()
                    $script:commands += [PSCustomObject]@{ id = $newId; cmd = $last }
                    $script:commands | ConvertTo-Json | Out-File $dbPath
                }
            }
            
            default {
                if ($key.Character -match '^[1-9]$') {
                    $num = [int]$key.Character - 1
                    if ($num -lt $commands.Count) { $selectedIndex = $num }
                }
            }
        }
    }
}

# --- Execution ---
return Show-QuickCommands
