param(
    [switch]$Rebuild,
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
$publish = Join-Path $PSScriptRoot "publish"
$executable = Join-Path $publish "codexeyes.exe"

if ($Rebuild -or -not (Test-Path $executable)) {
    & (Join-Path $PSScriptRoot "build.ps1") -Runtime $Runtime
}

if (-not (Test-Path $executable)) {
    throw "构建没有生成 codexeyes.exe"
}

Get-Process -Name "codexeyes" -ErrorAction SilentlyContinue | Stop-Process -Force
$startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
New-Item -ItemType Directory -Force -Path $startup | Out-Null
$shortcutPath = Join-Path $startup "codexeyes.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $executable
$shortcut.WorkingDirectory = $publish
$shortcut.Description = "codexeyes desktop usage widget"
$shortcut.IconLocation = "$executable,0"
$shortcut.Save()

Start-Process -FilePath $executable -WorkingDirectory $publish
Write-Host "Installed codexeyes and enabled Windows startup: $shortcutPath"
