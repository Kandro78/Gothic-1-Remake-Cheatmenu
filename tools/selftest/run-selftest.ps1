# Self-test bot for the G1R Cheat Menu, no computer use needed. Run it from the PowerShell tool in the
# background with the game closed (powershell -File fails on the execution policy, see deploy-mod.ps1):
#   run-selftest.ps1 -AutoLoad            checks + screenshots (about 3 min)
#   run-selftest.ps1 -AutoLoad -Soak      plus 3 minutes of opening and closing the menu (crash repro)
#   run-selftest.ps1 -AutoLoad -MakeTestSave   loads your last save, quicksaves it and keeps that
#                                         quicksave as the test save every later run starts from
#   run-selftest.ps1 -RestoreFrom <save-backups\selftest-...>   only clean up after a stopped run
# Other options: -Language en (the game language during the run; '' keeps yours), -UpdateBaseline
# (take this run's menu crops as the new reference), -NoTestSave (start from your last save).
# It backs up the saves, deploys the mod plus CMSelfTest.as (test only), puts the test save in place,
# starts the game, clicks Continue (and "Continue anyway" on the modlist dialog), then reads the
# test's lines from its save slot, captures a screenshot and a menu crop for every SHOT line,
# compares the crops with the last good run, closes the game, deploys the clean mod again and
# restores the saves. Exit code = number of failed checks (100 when the test did not finish).
# The clicks and keys go to the real mouse and keyboard: leave the PC alone while it runs.
param(
    [switch]$AutoLoad,
    [int]$TimeoutSec = 420,
    [string]$RestoreFrom,
    [switch]$MakeTestSave,
    [switch]$NoTestSave,
    [string]$Language = 'en',
    [switch]$Soak,
    [switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'
$game = 'G:\SteamLibrary\steamapps\common\Gothic 1 Remake'
$exe = Join-Path $game 'G1R-Win64-Shipping.exe'
$mod = Join-Path $game 'G1R\Mods\Kandro78-G1RCheatMenu'
$saved = Join-Path $env:LOCALAPPDATA 'G1R\Saved'
$saveGames = Join-Path $saved 'SaveGames'
$result = Join-Path $saveGames 'Kandro78-G1RCheatMenu-SelfTest.sav'
$shots = Join-Path $PSScriptRoot 'shots'
$baseline = Join-Path $PSScriptRoot 'baseline'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path # F:\Modding stuff\Gothic 1 Remake
$testSave = Join-Path $root 'selftest-save' # outside the repo: a save is personal data
$backup = Join-Path $root "save-backups\selftest-$(Get-Date -Format yyyyMMdd-HHmmss)"
if ($TimeoutSec -eq 420 -and $Soak) { $TimeoutSec = 660 }

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

function Get-GameRect {
    $r = New-Object G1RBot+RECT
    [G1RBot]::GetWindowRect((Get-GameWindow), [ref]$r) | Out-Null
    $r
}

# a different title means a script compile error dialog
function Assert-NoCompileError {
    $title = "$((Get-GameProcess).MainWindowTitle)".Trim() # the game's title ends in two spaces
    if ($title -and $title -ne 'Gothic 1 Remake') { throw "Unexpected game window '$title': probably a script compile error dialog (Copy to clipboard, then Get-Clipboard)." }
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
    $codes = @{ Enter = @(0x0D, 0x1C); Space = @(0x20, 0x39); F5 = @(0x74, 0x3F) }
    Show-Game
    $vk, $scan = $codes[$Name]
    [G1RBot]::keybd_event($vk, $scan, 8, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [G1RBot]::keybd_event($vk, $scan, 10, [UIntPtr]::Zero)
}

# FX / FY: position as a fraction of the game window, so it works at any resolution
function Send-Click([double]$FX, [double]$FY) {
    Show-Game
    $r = Get-GameRect
    [G1RBot]::SetCursorPos([int]($r.L + $FX * ($r.R - $r.L)), [int]($r.T + $FY * ($r.B - $r.T))) | Out-Null
    Start-Sleep -Milliseconds 300 # the menu highlights on hover first
    [G1RBot]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [G1RBot]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}

function Get-Screen {
    $r = Get-GameRect
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
    $g.Dispose()
    $bmp
}

# luminance of the pixels in a region given as fractions of the image: mean, spread, share above 150
function Measure-Region($Bmp, [double]$X0, [double]$Y0, [double]$X1, [double]$Y1) {
    $sum = 0.0; $sq = 0.0; $hi = 0; $n = 0
    for ($x = [int]($X0 * $Bmp.Width); $x -lt [int]($X1 * $Bmp.Width); $x += 4) {
        for ($y = [int]($Y0 * $Bmp.Height); $y -lt [int]($Y1 * $Bmp.Height); $y += 4) {
            $c = $Bmp.GetPixel($x, $y); $l = 0.3 * $c.R + 0.59 * $c.G + 0.11 * $c.B
            $sum += $l; $sq += $l * $l; $n++; if ($l -gt 150) { $hi++ }
        }
    }
    $mean = $sum / $n
    @{ Mean = $mean; Sd = [math]::Sqrt([math]::Max(0, $sq / $n - $mean * $mean)); Bright = 100.0 * $hi / $n }
}

# main menu: the bright "Fortfahren" label (21 % bright pixels there; loading, dialog and game <= 7 %).
# modlist dialog: its empty middle box is flat dark (mean 12, spread 0) and its title line has bright
# text; the box test alone also fires on the menu fading to black after Continue.
# Measured 2026-11-02 at 2560x1440.
function Test-Screen([string]$What) {
    $bmp = Get-Screen
    try {
        if ($What -eq 'menu') { return (Measure-Region $bmp 0.10 0.325 0.22 0.355).Bright -gt 14 }
        $m = Measure-Region $bmp 0.44 0.42 0.56 0.62
        $title = Measure-Region $bmp 0.26 0.31 0.47 0.335
        return $m.Mean -lt 20 -and $m.Sd -lt 2 -and $title.Bright -gt 3
    } finally { $bmp.Dispose() }
}

function Save-Shot([string]$Name, [int[]]$Crop) {
    Show-Game
    $bmp = Get-Screen
    $bmp.Save((Join-Path $shots "$Name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    if ($Crop) {
        $x0 = [math]::Max(0, $Crop[0] - 24); $y0 = [math]::Max(0, $Crop[1] - 24)
        $x1 = [math]::Min($bmp.Width, $Crop[2] + 24); $y1 = [math]::Min($bmp.Height, $Crop[3] + 24)
        $panel = $bmp.Clone((New-Object System.Drawing.Rectangle $x0, $y0, ($x1 - $x0), ($y1 - $y0)), $bmp.PixelFormat)
        $panel.Save((Join-Path $shots "$Name-panel.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $panel.Dispose()
    }
    $bmp.Dispose()
}

# mean luminance difference in percent of two images, both shrunk to 96 px wide
function Compare-Image([string]$A, [string]$B) {
    $ia = [System.Drawing.Image]::FromFile($A); $ib = [System.Drawing.Image]::FromFile($B)
    try {
        $h = [int](96 * $ia.Height / $ia.Width)
        $sa = New-Object System.Drawing.Bitmap $ia, 96, $h; $sb = New-Object System.Drawing.Bitmap $ib, 96, $h
        $d = 0.0
        for ($x = 0; $x -lt 96; $x++) { for ($y = 0; $y -lt $h; $y++) {
            $ca = $sa.GetPixel($x, $y); $cb = $sb.GetPixel($x, $y)
            $d += [math]::Abs((0.3 * $ca.R + 0.59 * $ca.G + 0.11 * $ca.B) - (0.3 * $cb.R + 0.59 * $cb.G + 0.11 * $cb.B))
        } }
        $sa.Dispose(); $sb.Dispose()
        100.0 * $d / (96 * $h * 255)
    } finally { $ia.Dispose(); $ib.Dispose() }
}

# the slot is a UE save: the lines are plain ASCII FStrings in it
function Read-Lines {
    if (-not (Test-Path $result) -or (Get-Item $result).LastWriteTime -lt $script:start) { return @() }
    try { $bytes = [IO.File]::ReadAllBytes($result) } catch { return @() } # the game may be writing it
    [regex]::Matches([Text.Encoding]::ASCII.GetString($bytes), 'CMT\|([\x20-\x7E]*)') | ForEach-Object { $_.Groups[1].Value }
}

# copy over an existing file only (AppData is sandboxed: a file created from here never reaches the game)
function Copy-Over([string]$From, [string]$To) {
    if (-not (Test-Path $To)) { return $false }
    Copy-Item $From $To -Force
    (Get-Item $To).LastWriteTime = Get-Date
    $true
}

# the test save: the quicksave slot file, the save index that lists it as the newest, and where the hero stood
function Use-TestSave {
    $info = Join-Path $testSave 'slot.txt'
    if ($NoTestSave -or $MakeTestSave -or -not (Test-Path $info)) {
        if (-not $MakeTestSave -and -not $NoTestSave) { Write-Host 'No test save yet (make one with -MakeTestSave): starting from your last save.' }
        return $null
    }
    $slot, $pos = Get-Content $info
    if (-not (Copy-Over (Join-Path $testSave "$slot.sav") (Join-Path $saveGames "$slot.sav"))) {
        Write-Host "Slot $slot.sav is gone from SaveGames and cannot be created from here: starting from your last save."
        return $null
    }
    Copy-Over (Join-Path $testSave 'PersistentDataList.sav') (Join-Path $saveGames 'PersistentDataList.sav') | Out-Null
    Write-Host "Test save $slot in place."
    $pos
}

function Save-TestSave([string]$Pos) {
    $before = @{}
    Get-ChildItem $saveGames -Filter 'G1R-*.sav' | ForEach-Object { $before[$_.Name] = $_.LastWriteTime }
    $t = Get-Date
    Send-Key F5
    $slotFile = $null
    for ($i = 0; $i -lt 60 -and -not $slotFile; $i++) {
        Start-Sleep 1
        if ($i % 15 -eq 14) { Send-Key Space; Start-Sleep 2; Send-Key F5 } # the loading picture may still have been up
        $slotFile = Get-ChildItem $saveGames -Filter 'G1R-*.sav' | Where-Object { $_.LastWriteTime -gt $t } | Select-Object -First 1
    }
    if (-not $slotFile) { throw 'F5 made no quicksave within 60 s.' }
    Start-Sleep 5 # the game also writes the index and the screenshot
    New-Item -ItemType Directory -Force $testSave | Out-Null
    Copy-Item $slotFile.FullName $testSave -Force
    Copy-Item (Join-Path $saveGames 'PersistentDataList.sav') $testSave -Force
    Set-Content (Join-Path $testSave 'slot.txt') @($slotFile.BaseName, $Pos)
    Write-Host "Test save kept: $($slotFile.Name) (hero at $Pos) in $testSave"
}

if ($RestoreFrom) {
    $backup = $RestoreFrom
} else {
    if (Get-Process G1R-Win64-Shipping -ErrorAction SilentlyContinue) { throw 'Close the game first.' }
    New-Item -ItemType Directory -Force $backup | Out-Null
    Copy-Item $saveGames $backup -Recurse
    Copy-Item (Join-Path $saved 'Mods.ini') $backup -ErrorAction SilentlyContinue
    Write-Host "Saves backed up to $backup"
}

$failed = 100
try {
    if ($RestoreFrom) { return }
    & (Join-Path $PSScriptRoot '..\deploy-mod.ps1') | Out-Null
    $test = Get-Content (Join-Path $PSScriptRoot 'CMSelfTest.as') -Raw
    $test = $test.Replace('const FString Mode = "test";', "const FString Mode = `"$(if ($MakeTestSave) { 'makesave' } else { 'test' })`";")
    $test = $test.Replace('const FString Language = "";', "const FString Language = `"$Language`";")
    $test = $test.Replace('const bool bSoak = false;', "const bool bSoak = $(if ($Soak) { 'true' } else { 'false' });")
    [IO.File]::WriteAllText((Join-Path $mod 'Script\CheatMenu\CMSelfTest.as'), $test) # no BOM
    New-Item -ItemType Directory -Force $shots | Out-Null
    Get-ChildItem $shots -Filter *.png | Remove-Item
    $expectedPos = Use-TestSave

    $script:start = Get-Date
    Start-Process -FilePath $exe -WorkingDirectory $game -ArgumentList '-Mods=Kandro78-G1RCheatMenu', '-as-development-mode'
    Write-Host 'Game started.'
    while ((Get-GameWindow) -eq [IntPtr]::Zero) {
        if (((Get-Date) - $script:start).TotalSeconds -gt 90) { throw 'No game window after 90 s.' }
        Start-Sleep 1
    }
    if ($AutoLoad) {
        $hits = 0
        while ($hits -lt 2) { # twice in a row, so a passing frame of the intro does not count
            if (((Get-Date) - $script:start).TotalSeconds -gt 150) { Save-Shot 'load-1-menu'; throw 'No main menu after 150 s (see shots\load-1-menu.png).' }
            Assert-NoCompileError
            Start-Sleep 2
            Show-Game # the screen tests read the screen, so the game has to be in front
            if (Test-Screen 'menu') { $hits++ } else { $hits = 0 }
        }
        Save-Shot 'load-1-menu'; Send-Click 0.160 0.339 # Continue (Fortfahren); the menu ignores Enter
        $hits = 0
        for ($i = 0; $i -lt 10 -and $hits -lt 2; $i++) {
            Start-Sleep 1
            if (Test-Screen 'dialog') { $hits++ } else { $hits = 0 }
        }
        # "different modlist" (after a mod version change): Continue anyway. Never Enter there: it could hit "Sync mods and restart game"
        if ($hits -ge 2) { Save-Shot 'load-2-modlist'; Send-Click 0.585 0.675 }
    } else {
        Write-Host 'Load a save (Continue); the test starts by itself 5 s later.'
    }

    $seen = 0
    $lastSpace = Get-Date
    while (((Get-Date) - $script:start).TotalSeconds -lt $TimeoutSec) {
        if (-not (Get-Process G1R-Win64-Shipping -ErrorAction SilentlyContinue)) { Write-Host 'FAIL the game closed (crash?)'; break }
        $lines = @(Read-Lines)
        # the loading picture waits for Space; Space in the game is a jump, so it stops once the test reports
        if ($AutoLoad -and $lines.Count -eq 0 -and ((Get-Date) - $lastSpace).TotalSeconds -gt 8) { Send-Key Space; $lastSpace = Get-Date }
        for (; $seen -lt $lines.Count; $seen++) {
            $line = $lines[$seen]
            Write-Host $line
            if ($line -match '^(START|READY) (-?\d+) (-?\d+) (-?\d+)') {
                $pos = "$($Matches[2]) $($Matches[3]) $($Matches[4])"
                if ($expectedPos) {
                    $a = $expectedPos -split ' ' | ForEach-Object { [double]$_ }; $b = $pos -split ' ' | ForEach-Object { [double]$_ }
                    $dist = [math]::Sqrt([math]::Pow($a[0] - $b[0], 2) + [math]::Pow($a[1] - $b[1], 2) + [math]::Pow($a[2] - $b[2], 2))
                    Write-Host ($(if ($dist -lt 2000) { 'INFO the test save was loaded' } else { "WARN the hero is $([int]$dist) units from the test save's spot: another save was loaded?" }))
                }
                if ($Matches[1] -eq 'READY') { Save-TestSave $pos; $failed = 0 }
            }
            if ($line -match '^SHOT (\d+) ([^|]*)(?:\|(\d+)\|(\d+)\|(\d+)\|(\d+))?$') {
                $crop = if ($Matches[3]) { [int[]]@($Matches[3], $Matches[4], $Matches[5], $Matches[6]) } else { $null }
                Save-Shot ('{0:D2}-{1}' -f [int]$Matches[1], ($Matches[2].Trim() -replace '[^\w]+', '-')) $crop
            }
            if ($line -match '^DONE \d+ passed, (\d+) failed') { $failed = [int]$Matches[1] }
        }
        if ($failed -ne 100) { break }
        Start-Sleep -Milliseconds 250
    }
    if ($failed -eq 100) {
        Write-Host 'TIMEOUT or crash: no DONE line.'
        if (Get-GameProcess) { Save-Shot 'timeout' } # where it got stuck
    }

    # menu crops against the last good run; differences above 4 % are worth a look
    $panels = @(Get-ChildItem $shots -Filter '*-panel.png')
    if ($panels.Count -gt 0) {
        $haveBaseline = (Test-Path $baseline) -and @(Get-ChildItem $baseline -Filter '*-panel.png').Count -gt 0
        if ($haveBaseline -and -not $UpdateBaseline) {
            foreach ($p in $panels) {
                $ref = Join-Path $baseline $p.Name
                if (-not (Test-Path $ref)) { Write-Host "NEW $($p.Name) (no reference)"; continue }
                $diff = Compare-Image $p.FullName $ref
                Write-Host ('{0} {1} {2:N1} % different from the reference' -f $(if ($diff -gt 4) { 'CHANGED' } else { 'same' }), $p.Name, $diff)
            }
        }
        if (($UpdateBaseline -or -not $haveBaseline) -and $failed -eq 0) {
            New-Item -ItemType Directory -Force $baseline | Out-Null
            $panels | Copy-Item -Destination $baseline -Force
            Write-Host "Reference crops saved to $baseline"
        }
    }
} finally {
    Stop-Process -Name G1R-Win64-Shipping -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    & (Join-Path $PSScriptRoot '..\deploy-mod.ps1') | Out-Null # the clean mod, without CMSelfTest.as

    # restore by copying over the changed files (AppData is sandboxed: never delete and recreate)
    foreach ($f in Get-ChildItem (Join-Path $backup 'SaveGames') -File) {
        $live = Join-Path $saveGames $f.Name
        if (-not (Test-Path $live) -or (Get-FileHash $live).Hash -ne (Get-FileHash $f.FullName).Hash) {
            Copy-Item $f.FullName $live -Force
            (Get-Item $live).LastWriteTime = Get-Date
            Write-Host "Restored $($f.Name)"
        }
    }
    foreach ($f in Get-ChildItem $saveGames -File) {
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
