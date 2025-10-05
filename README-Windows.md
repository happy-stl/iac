# Windows WSL2 Setup with Ansible

This repository now supports both Linux and Windows environments. The Windows portion sets up WSL2 (Windows Subsystem for Linux) with development tools.

## Prerequisites

### For Windows:
1. Windows 10 version 2004 and higher (Build 19041 and higher) or Windows 11
2. PowerShell 5.1 or higher
3. Ansible installed on Windows (or run from WSL2/Linux)
4. WinRM configured for remote management

### For Linux:
- Standard Ansible requirements

## Installation

1. Install required Ansible collections:
```bash
ansible-galaxy collection install -r requirements.yml
```

2. Configure WinRM on Windows (if running Ansible from Linux):
```powershell
# Run as Administrator
winrm quickconfig
winrm set winrm/config/service/auth @{Basic="true"}
winrm set winrm/config/service @{AllowUnencrypted="true"}
```

## Usage

### Running on Linux (current setup):
```bash
# Run all playbooks (Linux only)
ansible-playbook -i inventories/local.yml playbooks/site.yml

# Run specific Linux playbooks
ansible-playbook -i inventories/local.yml playbooks/dev-setup.yml
ansible-playbook -i inventories/local.yml playbooks/gaming-setup.yml
```

### Running on Windows:
```bash
# Run Windows WSL2 setup
ansible-playbook -i inventories/local.yml playbooks/windows-only.yml

# Or run the main site playbook (will detect OS)
ansible-playbook -i inventories/local.yml playbooks/site.yml
```

### Running from Windows to configure WSL2:
```powershell
# From PowerShell on Windows
ansible-playbook -i inventories/local.yml playbooks/windows-only.yml --connection=local
```

## What Gets Configured

### Linux Environment:
- Development tools (git, nvim, tmux)
- Gaming setup (Mednafen)
- Common packages and directories

### Windows Environment:
- WSL2 installation and configuration
- Ubuntu distributions (20.04 and 22.04)
- Windows Terminal
- Git for Windows
- VS Code
- Chocolatey package manager
- Development directory structure

## Inventory Configuration

The inventory supports both Linux and Windows hosts:

```yaml
all:
  children:
    local:                    # Linux hosts
      hosts:
        localhost:
          ansible_connection: local
    windows_hosts:           # Windows hosts
      hosts:
        windows-desktop:
          ansible_connection: winrm
          ansible_user: Administrator
          ansible_password: your_password
```

## WSL2 Configuration

The Windows setup creates a `.wslconfig` file with:
- 4GB memory allocation
- 2 CPU cores
- 2GB swap
- Localhost forwarding enabled

## Troubleshooting

### WinRM Issues:
```powershell
# Check WinRM status
winrm get winrm/config

# Restart WinRM service
Restart-Service WinRM
```

### WSL2 Issues:
```powershell
# Check WSL status
wsl --list --verbose

# Restart WSL
wsl --shutdown
```

### Ansible Connection Issues:
```bash
# Test connection
ansible windows_hosts -i inventories/local.yml -m win_ping
```

## Customization

Edit the following files to customize the setup:

- `roles/windows-wsl2-setup/defaults/main.yml` - Windows-specific variables
- `inventories/local.yml` - Host configuration
- `playbooks/windows-only.yml` - Windows playbook tasks

## Security Notes

- The current setup uses basic authentication for WinRM
- For production use, consider using HTTPS and certificate-based authentication
- Update passwords and usernames in the inventory file