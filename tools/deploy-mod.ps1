# Copies the mod package (Kandro78-G1RCheatMenu) into the game's Mods folder, mirroring it:
# files that are no longer in the source are removed from the game copy too.
# -Launch also starts the game with the mod and AngelScript development mode (hot reload).
param([switch]$Launch)

$game = 'G:\SteamLibrary\steamapps\common\Gothic 1 Remake'
$src = Join-Path $PSScriptRoot '..\Kandro78-G1RCheatMenu'
$dst = Join-Path $game 'G1R\Mods\Kandro78-G1RCheatMenu'

robocopy $src $dst /MIR /NJH /NJS /NDL /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
Get-ChildItem $dst -Recurse -File | ForEach-Object { $_.FullName.Substring($dst.Length + 1) }

if ($Launch) {
    Start-Process -FilePath (Join-Path $game 'G1R-Win64-Shipping.exe') -WorkingDirectory $game `
        -ArgumentList '-Mods=Kandro78-G1RCheatMenu', '-as-development-mode'
}
