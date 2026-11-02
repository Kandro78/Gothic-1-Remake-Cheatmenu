# Self-test bot for the G1R Cheat Menu, no computer use needed. It backs up the saves, deploys the mod
# plus CMSelfTest.as (test only), starts the game, loads the last save (-AutoLoad sends the keys,
# otherwise click Continue yourself), then reads the test's lines from its save slot, captures a
# screenshot for every SHOT line into shots\, closes the game, deploys the clean mod again and
# restores the saves. Exit code = number of failed checks (or 100 when the test did not finish).
# Run it from the PowerShell tool (powershell -File fails on the execution policy, see deploy-mod.ps1).
#   -RestoreFrom <save-backups\selftest-...>: only close the game, deploy the clean mod and restore
#   that backup (after a run that was stopped before it could clean up).
param(
    [switch]$AutoLoad,
    [int]$TimeoutSec = 420,
    [string]$RestoreFrom
)

$ErrorActionPreference = 'Stop'
$game = 'G:\SteamLibrary\steamapps\common\Gothic 1 Remake'
$exe = Join-Path $game 'G1R-Win64-Shipping.exe'
$mod = Join-Path $game 'G1R\Mods\Kandro78-G1RCheatMenu'
$saved = Join-Path $env:LOCALAPPDATA 'G1R\Saved'
$result = Join-Path $saved 'SaveGames\Kandro78-G1RCheatMenu-SelfTest.sav'
$shots = Join-Path $PSScriptRoot 'shots'
$backup = Join-Path $PSScriptRoot "..\..\..\save-backups\selftest-$(Get-Date -Format yyyyMMdd-HHmmss)"

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class G1RBot {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
}
'@
[G1RBot]::SetProcessDPIAware() | Out-Null

# the exe in the game folder is a stub that starts G1R\Binaries\Win64\G1R-Win64-Shipping.exe (same
# name); only that second process has the window
function Get-GameProcess {
    Get-Process G1R-Win64-Shipping -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
}

function Get-GameWindow {
    $p = Get-GameProcess
    if ($p) { $p.MainWindowHandle } else { [IntPtr]::Zero }
}

function Show-Game {
    $h = Get-GameWindow
    if ([G1RBot]::GetForegroundWindow() -ne $h) {
        [G1RBot]::keybd_event(0x12, 0x38, 0, [UIntPtr]::Zero) # Alt tap lets SetForegroundWindow through; Alt is the game's dodge, so only when not in front
        [G1RBot]::keybd_event(0x12, 0x38, 2, [UIntPtr]::Zero)
        [G1RBot]::SetForegroundWindow($h) | Out-Null
        Start-Sleep -Milliseconds 400
    }
}

# scan codes, since the game reads those (see testing\Gothic1Remake.md)
function Send-Key([string]$Name) {
    $codes = @{ Enter = @(0x0D, 0x1C); Space = @(0x20, 0x39) }
    Show-Game
    $vk, $scan = $codes[$Name]
    [G1RBot]::keybd_event($vk, $scan, 8, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [G1RBot]::keybd_event($vk, $scan, 10, [UIntPtr]::Zero)
}

# FX / FY: position as a fraction of the game window, so it works at any resolution
function Send-Click([double]$FX, [double]$FY) {
    Show-Game
    $r = New-Object G1RBot+RECT
    [G1RBot]::GetWindowRect((Get-GameWindow), [ref]$r) | Out-Null
    [G1RBot]::SetCursorPos([int]($r.L + $FX * ($r.R - $r.L)), [int]($r.T + $FY * ($r.B - $r.T))) | Out-Null
    Start-Sleep -Milliseconds 300 # the menu highlights on hover first
    [G1RBot]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [G1RBot]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}

function Save-Shot([string]$Name) {
    Show-Game
    $r = New-Object G1RBot+RECT
    [G1RBot]::GetWindowRect((Get-GameWindow), [ref]$r) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
    $bmp.Save((Join-Path $shots "$Name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

# the slot is a UE save: the lines are plain ASCII FStrings in it
function Read-Lines {
    if (-not (Test-Path $result) -or (Get-Item $result).LastWriteTime -lt $script:start) { return @() }
    try { $bytes = [IO.File]::ReadAllBytes($result) } catch { return @() } # the game may be writing it
    [regex]::Matches([Text.Encoding]::ASCII.GetString($bytes), 'CMT\|([\x20-\x7E]*)') | ForEach-Object { $_.Groups[1].Value }
}

if ($RestoreFrom) {
    $backup = $RestoreFrom # only clean up after a run that was stopped
} else {
    if (Get-Process G1R-Win64-Shipping -ErrorAction SilentlyContinue) { throw 'Close the game first.' }
    New-Item -ItemType Directory -Force $backup | Out-Null
    Copy-Item (Join-Path $saved 'SaveGames') $backup -Recurse
    Copy-Item (Join-Path $saved 'Mods.ini') $backup -ErrorAction SilentlyContinue
    Write-Host "Saves backed up to $((Resolve-Path $backup).Path)"
}

$failed = 100
try {
    if ($RestoreFrom) { return }
    & (Join-Path $PSScriptRoot '..\deploy-mod.ps1') | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'CMSelfTest.as') (Join-Path $mod 'Script\CheatMenu\')
    New-Item -ItemType Directory -Force $shots | Out-Null
    Get-ChildItem $shots -Filter *.png | Remove-Item

    $script:start = Get-Date
    Start-Process -FilePath $exe -WorkingDirectory $game -ArgumentList '-Mods=Kandro78-G1RCheatMenu', '-as-development-mode'
    Write-Host 'Game started.'
    while ((Get-GameWindow) -eq [IntPtr]::Zero) {
        if (((Get-Date) - $script:start).TotalSeconds -gt 90) { throw 'No game window after 90 s.' }
        Start-Sleep 1
    }
    if ($AutoLoad) {
        Start-Sleep 45
        $title = "$((Get-GameProcess).MainWindowTitle)".Trim() # the game's title ends in two spaces
        if ($title -ne 'Gothic 1 Remake') { throw "Unexpected game window '$title': probably a script compile error dialog (Copy to clipboard, then Get-Clipboard)." }
        Save-Shot 'load-1-menu';      Send-Click 0.160 0.339 # Continue (Fortfahren) on the main menu; Enter does nothing there
        Start-Sleep 6;  Save-Shot 'load-2-modlist';  Send-Click 0.585 0.675 # "different modlist": Continue anyway (never Enter: it could hit "Sync mods and restart game")
        Start-Sleep 30; Save-Shot 'load-3-loading';  Send-Key Space # close the loading picture
        Start-Sleep 5;  Save-Shot 'load-4-ingame'
    } else {
        Write-Host 'Load a save (Continue); the test starts by itself 5 s later.'
    }

    $seen = 0
    while (((Get-Date) - $script:start).TotalSeconds -lt $TimeoutSec) {
        if (-not (Get-Process G1R-Win64-Shipping -ErrorAction SilentlyContinue)) { Write-Host 'The game closed.'; break }
        $lines = @(Read-Lines)
        for (; $seen -lt $lines.Count; $seen++) {
            $line = $lines[$seen]
            Write-Host $line
            if ($line -match '^SHOT (\d+) (.*)$') { Save-Shot ('{0:D2}-{1}' -f [int]$Matches[1], ($Matches[2] -replace '[^\w]+', '-')) }
            if ($line -match '^DONE \d+ passed, (\d+) failed') { $failed = [int]$Matches[1] }
        }
        if ($failed -ne 100) { break }
        Start-Sleep -Milliseconds 250
    }
    if ($failed -eq 100) { Write-Host 'TIMEOUT: no DONE line.' }
} finally {
    Stop-Process -Name G1R-Win64-Shipping -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    & (Join-Path $PSScriptRoot '..\deploy-mod.ps1') | Out-Null # the clean mod, without CMSelfTest.as

    # restore by copying over the changed files (AppData is sandboxed: never delete and recreate)
    foreach ($f in Get-ChildItem (Join-Path $backup 'SaveGames') -File) {
        $live = Join-Path $saved "SaveGames\$($f.Name)"
        if (-not (Test-Path $live) -or (Get-FileHash $live).Hash -ne (Get-FileHash $f.FullName).Hash) {
            Copy-Item $f.FullName $live -Force
            (Get-Item $live).LastWriteTime = Get-Date
            Write-Host "Restored $($f.Name)"
        }
    }
    foreach ($f in Get-ChildItem (Join-Path $saved 'SaveGames') -File) {
        if (-not (Test-Path (Join-Path $backup "SaveGames\$($f.Name)"))) { Write-Host "New file left in place: $($f.Name)" }
    }
    $ini = Join-Path $backup 'Mods.ini'
    if ((Test-Path $ini) -and (Get-FileHash $ini).Hash -ne (Get-FileHash (Join-Path $saved 'Mods.ini')).Hash) {
        Copy-Item $ini (Join-Path $saved 'Mods.ini') -Force
        Write-Host 'Restored Mods.ini'
    }
}
Write-Host "Screenshots: $shots"
exit $failed
