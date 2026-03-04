$ErrorActionPreference = "Stop"

$opensshDir = Join-Path $env:WINDIR "System32\OpenSSH"
$sshdConfig = Join-Path $env:ProgramData "ssh\sshd_config"
$sshdConfigDefault = Join-Path $opensshDir "sshd_config_default"

if (Test-Path $opensshDir) {
  if ($env:PATH -notlike "*$opensshDir*") {
    $env:PATH = "$opensshDir;$env:PATH"
  }
}

$password = $env:ADMIN_PASSWORD
if ([string]::IsNullOrWhiteSpace($password)) {
  $password = "ChangeMeNow123!"
}

net user ContainerAdministrator $password | Out-Null

New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null

$pwshLong = "C:\Program Files\PowerShell\7\pwsh.exe"
$pwshPath = $pwshLong
try {
  $short = cmd /c for %I in ("C:\Program Files\PowerShell\7\pwsh.exe") do @echo %~sI
  if ($short) { $pwshPath = $short.Trim() }
} catch { }

New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -Value $pwshPath -PropertyType String -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShellCommandOption" -Value "-c" -PropertyType String -Force | Out-Null

if (-not (Test-Path $sshdConfig)) {
  New-Item -ItemType Directory -Force (Split-Path $sshdConfig) | Out-Null
  if (Test-Path $sshdConfigDefault) {
    Copy-Item $sshdConfigDefault $sshdConfig -Force
  }
}

if (-not (Test-Path (Join-Path $env:ProgramData "ssh\ssh_host_ed25519_key"))) {
  & (Join-Path $opensshDir "ssh-keygen.exe") -A | Out-Null
}

if (Test-Path $sshdConfig) {
  $lines = Get-Content $sshdConfig

  if ($lines -match "^\s*#?\s*PasswordAuthentication\s+") {
    $lines = $lines -replace "^\s*#?\s*PasswordAuthentication\s+.*$", "PasswordAuthentication yes"
  } else {
    $lines += "PasswordAuthentication yes"
  }

  if ($lines -match "^\s*#?\s*PubkeyAuthentication\s+") {
    $lines = $lines -replace "^\s*#?\s*PubkeyAuthentication\s+.*$", "PubkeyAuthentication yes"
  } else {
    $lines += "PubkeyAuthentication yes"
  }

  Set-Content -Path $sshdConfig -Value $lines -Encoding ascii
}

if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

Set-Service -Name sshd -StartupType Automatic
try { Set-Service -Name ssh-agent -StartupType Automatic } catch { }

try { Start-Service ssh-agent } catch { }

if ((Get-Service sshd).Status -ne "Running") {
  Start-Service sshd
} else {
  Restart-Service sshd
}

Write-Host ""
Write-Host "============================================"
Write-Host " psmux dev container ready"
Write-Host "============================================"
Write-Host " SSH  : ContainerAdministrator@<host>:22"
Write-Host " Pass : (value of ADMIN_PASSWORD env var)"
Write-Host " Rust : $(& rustc --version 2>$null)"
Write-Host " Cargo: $(& cargo --version 2>$null)"
Write-Host "============================================"
Write-Host ""
Write-Host "Quick start:"
Write-Host "  git clone https://github.com/marlocarlo/psmux.git"
Write-Host "  cd psmux"
Write-Host "  cargo install --path ."
Write-Host ""

while ($true) { Start-Sleep -Seconds 3600 }
