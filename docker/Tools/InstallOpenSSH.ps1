$ErrorActionPreference = "Stop"

$url = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.8.3.0p2-Preview/OpenSSH-Win64.zip"
$zipPath = "C:\openssh.zip"
$extractDir = "C:\OpenSSH-Win64"
$targetDir = "C:\Windows\System32\OpenSSH"

Write-Host "Downloading Win32-OpenSSH..."
Invoke-WebRequest $url -OutFile $zipPath

Write-Host "Extracting..."
Expand-Archive $zipPath -DestinationPath "C:\" -Force
Remove-Item $zipPath -Force

# Copy sshd and related files to the existing OpenSSH directory
$filesToCopy = @("sshd.exe", "sshd_config_default", "libcrypto.dll", "sftp-server.exe")
foreach ($f in $filesToCopy) {
    $src = Join-Path $extractDir $f
    if (Test-Path $src) {
        Copy-Item $src $targetDir -Force
        Write-Host "  Copied $f"
    }
}

Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OpenSSH Server installed."
