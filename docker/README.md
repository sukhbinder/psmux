# psmux Docker Dev Environment

A Windows container with Rust (MSVC), Visual Studio Build Tools, and OpenSSH — ready to build and run psmux.

## What's inside

| Component | Details |
|-----------|---------|
| Base image | `mcr.microsoft.com/powershell:windowsservercore-ltsc2022` |
| Rust | stable-x86_64-pc-windows-msvc via rustup |
| MSVC | Visual Studio Build Tools 2022 (`cl.exe`, `link.exe`) |
| SSH | OpenSSH Server (password + pubkey auth) |
| Shell | PowerShell 7 with auto-loaded VS dev environment |
| Git | MinGit for cloning repos |

## Quick start

### 1. Build the image

```powershell
cd docker
docker build -t psmux-dev .
```

> **Note:** The build takes a while (~15-30 min) because it downloads and installs Visual Studio Build Tools. The resulting image is large (~15 GB). This is expected for Windows MSVC containers.

### 2. Run the container

**Local only (safest):**

```powershell
docker run -d --name psmux-dev `
  -p 127.0.0.1:2222:22 `
  -e ADMIN_PASSWORD=YourStrongPassword123! `
  psmux-dev
```

**LAN accessible:**

```powershell
docker run -d --name psmux-dev `
  -p 2222:22 `
  -e ADMIN_PASSWORD=YourStrongPassword123! `
  psmux-dev
```

### 3. SSH in

```powershell
ssh ContainerAdministrator@localhost -p 2222
```

### 4. Build psmux

```powershell
git clone https://github.com/marlocarlo/psmux.git
cd psmux
cargo install --path .
psmux --version
```

## Verifying the toolchain

After SSH-ing in, these should all work:

```powershell
rustc --version
cargo --version
where cl
where link
```

## Mount your local source

To work on psmux source from the host without cloning inside the container:

```powershell
docker run -d --name psmux-dev `
  -p 127.0.0.1:2222:22 `
  -e ADMIN_PASSWORD=YourStrongPassword123! `
  -v C:\path\to\psmux:C:\psmux `
  psmux-dev
```

Then inside the container:

```powershell
cd C:\psmux
cargo build --release
```

## Check port mapping

```powershell
docker port psmux-dev 22
```

## Safety notes

- Prefer `127.0.0.1` binding if you only need local access
- Always set `ADMIN_PASSWORD` at run time — never use the default in production
- Do not expose this container to the public internet with a simple password

## File layout

```
docker/
  Dockerfile
  README.md
  Tools/
    StartContainer.ps1      # Entrypoint: starts sshd, sets password, keeps container alive
    ImportVsDevEnv.ps1       # Loads VS dev environment (cl.exe, link.exe) into PowerShell
  Profile/
    Microsoft.PowerShell_profile.ps1   # Auto-loads Rust + MSVC env on every shell
```
