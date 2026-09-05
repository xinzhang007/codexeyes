$ErrorActionPreference = "Stop"
Get-Process -Name "codexeyes" -ErrorAction SilentlyContinue | Stop-Process -Force
$shortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\codexeyes.lnk"
Remove-Item $shortcut -Force -ErrorAction SilentlyContinue
Write-Host "Removed codexeyes startup entry. You can delete this repository folder when ready."
