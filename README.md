# Ansible Roles Repository

This repository contains Ansible roles for setting up development and gaming environments on Linux systems.

## Quick Start

### Prerequisites
- Ansible installed on your system
- Python 3.x
- sudo privileges

### Running Playbooks

You can run playbooks directly:

```bash
# Development environment
ansible-playbook -i inventories/local.yml playbooks/dev-setup.yml

# Gaming setup
ansible-playbook -i inventories/local.yml playbooks/gaming-setup.yml

# Complete setup
ansible-playbook -i inventories/local.yml playbooks/site.yml
```

## Roles

This repository contains the following Ansible roles:

| Role | Description | Dependencies |
| ---- | ----------- | ------------ |
| **common** | Base role that provides essential system setup and development tools | None |
| **mednafen-gaming** | Configures Mednafen emulator for gaming with proper audio, video, and controller settings | common |
| **nvim-config** | Sets up Neovim with auto-updating buffer configuration for better development experience | common |
| **university** | SIUE setup. Linux: campus Kerberos and the Engineering copiers. Windows: connects the PC to the copiers a Linux machine shares | siue-kerberos, siue-printing, siue-printing-windows |
| **siue-kerberos** | Kerberos client for the `CAMPUS.SIUE.EDU` Active Directory realm, with an hourly ticket refresh | None |
| **siue-printing** | CUPS queues for the Engineering Kyocera copiers through the campus print server, with Kerberos and job accounting; optionally shared to Windows PCs over HTTPS | siue-common, siue-kerberos |
| **siue-common** | Settings both copier roles share: the queues, the shared-queue suffix, the certificate path | None |
| **siue-printing-windows** | Trusts the Linux print server's certificate on a Windows PC and adds the shared copiers as HTTPS printers | siue-common |

## University (SIUE) setup

Fedora only: the Kyocera driver is an RPM.

```bash
ansible-playbook -K playbooks/university.yml
siue-keytab
```

The playbook prompts for your CAMPUS username, your Kyocera copier account ID
and any Windows PCs to share the copiers with, and keeps none of them in the
repository. `siue-keytab` asks for your campus password once, so an hourly
timer can keep a Kerberos ticket for printing.

### Connecting a Windows PC

The Windows side is run **from the Linux print server**, not from Windows,
after the Linux run above has shared the copiers with the PC's address.
`playbooks/windows.yml` sets the PC up: Shift+Enter as a new line in Windows
Terminal, the Linux machine's certificate, and both copiers.

1. On the PC, once: enable WinRM over HTTPS. The PowerShell is in the guide's
   [Connecting a Windows PC with Ansible](docs/siue-printing/siue-printing.md#connecting-a-windows-pc-with-ansible)
   section. It survives reboots. To check it, run
   `winrm enumerate winrm/config/listener`: one listener should show
   `Transport = HTTPS` and `Port = 5986`.
2. On the Linux machine, once:
   ```bash
   sudo dnf install -y python3-winrm python3-requests-kerberos python3-kerberos
   mkdir -p ~/.config/siue
   cp inventories/siue-windows.example.yml ~/.config/siue/windows.yml
   ${EDITOR:-nano} ~/.config/siue/windows.yml   # fill in <pc-name> and <campus-username>
   ```
3. Run it, now and for every new PC added to the file:
   ```bash
   ansible-playbook -i ~/.config/siue/windows.yml playbooks/windows.yml
   ```

The full guide, including the manual steps,
is [docs/siue-printing/siue-printing.md](docs/siue-printing/siue-printing.md).
It is written for [stencil](https://github.com/grimwm/stencil); to build the
styled HTML page:

```bash
cd docs && make gen
cd siue-printing && make doc     # writes siue-printing.html
```

## Configuration

### Inventory
The `inventories/local.yml` file is configured for local execution. Modify it or create a new one
to target remote hosts if needed.

### Role Variables

Each role has configurable variables in their respective `defaults/main.yml` files.

## License

This project is licensed under the MIT License: see the [LICENSE](LICENSE) file for details.
