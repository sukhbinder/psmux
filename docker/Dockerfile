# escape=`
# psmux build environment: Windows + Rust (MSVC) + OpenSSH
# Build:  docker build -t psmux-dev .
# Run:    docker run -d --name psmux-dev -p 127.0.0.1:2222:22 -e ADMIN_PASSWORD=YourPass123! psmux-dev
# SSH:    ssh ContainerAdministrator@localhost -p 2222
FROM mcr.microsoft.com/powershell:windowsservercore-ltsc2022

SHELL ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

ENV VS_INSTALL_PATH="C:\BuildTools"
ENV RUSTUP_HOME="C:\rustup"
ENV CARGO_HOME="C:\cargo"
ENV ADMIN_PASSWORD="ChangeMeNow123!"
ENV PATH="C:\cargo\bin;C:\Windows\System32\OpenSSH;${PATH}"

# Create directories
RUN $ErrorActionPreference = "Stop" ; `
    New-Item -ItemType Directory -Force C:\Tools | Out-Null ; `
    New-Item -ItemType Directory -Force C:\Profile | Out-Null ; `
    New-Item -ItemType Directory -Force "C:\Users\ContainerAdministrator\Documents\PowerShell" | Out-Null

# Install Rust via rustup (stable MSVC)
RUN $ErrorActionPreference = "Stop" ; `
    Invoke-WebRequest https://win.rustup.rs -OutFile C:\rustup-init.exe ; `
    Start-Process -FilePath C:\rustup-init.exe -ArgumentList "-y" -Wait ; `
    Remove-Item C:\rustup-init.exe -Force ; `
    & "$env:CARGO_HOME\bin\rustup.exe" default stable-x86_64-pc-windows-msvc ; `
    & "$env:CARGO_HOME\bin\rustc.exe" --version ; `
    & "$env:CARGO_HOME\bin\cargo.exe" --version

# Install Visual Studio Build Tools (MSVC linker + Windows SDK)
RUN $ErrorActionPreference = "Stop" ; `
    Invoke-WebRequest https://aka.ms/vs/17/release/vs_BuildTools.exe -OutFile C:\vs_BuildTools.exe ; `
    Start-Process -FilePath C:\vs_BuildTools.exe -ArgumentList @( `
      "--quiet","--wait","--norestart","--nocache", `
      "--installPath",$env:VS_INSTALL_PATH, `
      "--add","Microsoft.VisualStudio.Workload.VCTools", `
      "--add","Microsoft.VisualStudio.Component.VC.Tools.x86.x64", `
      "--add","Microsoft.VisualStudio.Component.Windows10SDK.19041", `
      "--log","C:\vsbuildtools-install.log" `
    ) -Wait ; `
    Remove-Item C:\vs_BuildTools.exe -Force ; `
    if (-not (Test-Path "$env:VS_INSTALL_PATH\VC\Tools\MSVC")) { `
      Write-Host "Build Tools install failed. Log tail:" ; `
      Get-Content C:\vsbuildtools-install.log -Tail 200 ; `
      throw "MSVC toolset missing" ; `
    }

# Install OpenSSH Server + Client
RUN $ErrorActionPreference = "Stop" ; `
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 ; `
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Install git so users can clone repos inside the container
RUN $ErrorActionPreference = "Stop" ; `
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/MinGit-2.47.1.2-64-bit.zip" -OutFile C:\git.zip ; `
    Expand-Archive C:\git.zip -DestinationPath C:\git -Force ; `
    Remove-Item C:\git.zip -Force ; `
    $env:PATH = "C:\git\cmd;$env:PATH" ; `
    [Environment]::SetEnvironmentVariable("PATH", "C:\git\cmd;$([Environment]::GetEnvironmentVariable('PATH','Machine'))", "Machine")

# Copy helper scripts and profile
COPY Tools\ImportVsDevEnv.ps1   C:\Tools\ImportVsDevEnv.ps1
COPY Tools\StartContainer.ps1   C:\Tools\StartContainer.ps1
COPY Profile\Microsoft.PowerShell_profile.ps1 C:\Users\ContainerAdministrator\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

EXPOSE 22

CMD ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\Tools\\StartContainer.ps1"]
