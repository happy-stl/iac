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

## Configuration

### Inventory
The `inventories/local.yml` file is configured for local execution. Modify it or create a new one
to target remote hosts if needed.

### Role Variables

Each role has configurable variables in their respective `defaults/main.yml` files.

## License

This project is open source. Feel free to modify and distribute as needed.
