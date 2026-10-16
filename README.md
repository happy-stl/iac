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
| **university** | Everything a Linux machine at SIUE needs: campus Kerberos and the Engineering copiers | siue-kerberos, siue-printing |
| **siue-kerberos** | Kerberos client for the `CAMPUS.SIUE.EDU` Active Directory realm | None |
| **siue-printing** | CUPS queues for the Engineering Kyocera copiers through `\\kyocera`, with Kerberos and job accounting; optionally shared to Windows PCs | siue-kerberos |

## University (SIUE) setup

Fedora only: the Kyocera driver is an RPM.

```bash
ansible-playbook -K playbooks/university.yml
kinit <your-username>@CAMPUS.SIUE.EDU
```

The playbook prompts for two things and stores neither:

- **Kyocera account ID**: your copier job-accounting code. It is written into
  every job, so each person runs the playbook with their own.
- **Windows PCs to share with**: IPv4 addresses, comma-separated, or blank.
  Each listed PC may print to an `<queue>-win` twin of every queue, and those
  jobs reach the print server under *your* campus login. Only list your own
  machines.

It creates `ENG2ndFloorKyocera` (TASKalfa 6003i) and `ENG3rdFloorKyocera`
(TASKalfa 7003i); add copiers in `siue_print_queues`
(`roles/siue-printing/defaults/main.yml`).

Printing uses your Kerberos ticket rather than a stored password. It lasts
about 10 hours and renews for up to 7 days, so run `kinit` after logging in.
A job sent without a valid ticket waits in the queue as "held for
authentication" until you do.

### Adding a shared queue on Windows

Settings → Bluetooth & devices → Printers & scanners → Add device →
**Add manually** → **Select a shared printer by name**, and enter

```text
http://<linux-host>:631/printers/ENG2ndFloorKyocera-win
```

Accept the Microsoft IPP Class Driver Windows offers. The Linux machine runs
the Kyocera driver and adds the account ID, so Windows needs neither.

## Configuration

### Inventory
The `inventories/local.yml` file is configured for local execution. Modify it or create a new one
to target remote hosts if needed.

### Role Variables

Each role has configurable variables in their respective `defaults/main.yml` files.

## License

This project is licensed under the MIT License: see the [LICENSE](LICENSE) file for details.
