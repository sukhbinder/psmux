# escape=`
# psmux build environment: Windows + Rust (MSVC) + OpenSSH
# Build:  docker build -t psmux-dev .
# Run:    docker run -d --name psmux-dev -p 127.0.0.1:2222:22 -e ADMIN_PASSWORD=YourPass123! psmux-dev
# SSH:    ssh ContainerAdministrator@localhost -p 2222
FROM mcr.microsoft.com/powershell:windowsservercore-ltsc2022

# NOTE: We keep the default cmd shell for RUN steps and invoke pwsh explicitly.
# Using SHELL ["pwsh",...] breaks Hyper-V isolated builds on Win11 25H2 hosts.

ENV VS_INSTALL_PATH="C:\BuildTools"
ENV RUSTUP_HOME="C:\rustup"
ENV CARGO_HOME="C:\cargo"
ENV PATH="C:\cargo\bin;C:\Windows\System32\OpenSSH;C:\Program Files\PowerShell\latest;${PATH}"

# Create directories and copy all scripts first
RUN mkdir C:\Tools && mkdir C:\Profile && mkdir "C:\Users\ContainerAdministrator\Documents\PowerShell"
COPY Tools\  C:\Tools\
COPY Profile\ C:\Users\ContainerAdministrator\Documents\PowerShell\

# Single combined install step: Rust + VS Build Tools + OpenSSH + Git + cleanup
# (Combined to avoid Docker layer commit failures from VS Build Tools long paths)
RUN pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\Tools\InstallAll.ps1

EXPOSE 22

CMD ["pwsh", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\Tools\\StartContainer.ps1"]
