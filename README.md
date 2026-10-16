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
siue-keytab
```

The playbook asks for everything personal, so nothing about you is kept in
the repository, and the account ID is kept out of `ansible.log`. On the
machine itself, the account ID is stored in each queue's driver settings
(`/etc/cups/ppd/<queue>.ppd`, readable by root and the `lp` group) because
CUPS writes it into every job from there. Press Enter to accept a default:

| Prompt | Default | Used for |
| ------ | ------- | -------- |
| CAMPUS username | your Linux login name | Kerberos login to the print server |
| Kyocera copier account ID | none: required | Written into every job as the copier's job-accounting code |
| Windows PCs to share with | none | IPv4 addresses, comma-separated, that may print through this machine |

To skip the prompts, pass the answers on the command line:

```bash
ansible-playbook -K playbooks/university.yml \
  -e siue_campus_user_input=<campus-username> \
  -e siue_print_account_id=<account-id> \
  -e siue_print_share_clients_csv=<windows-pc-ip>
```

It creates `ENG2ndFloorKyocera` (TASKalfa 6003i) and `ENG3rdFloorKyocera`
(TASKalfa 7003i); add copiers in `siue_print_queues`
(`roles/siue-printing/defaults/main.yml`).

### Kerberos tickets

Printing uses your Kerberos ticket rather than a stored password. A ticket
lasts about 10 hours; the role installs a user timer, `siue-krb-refresh`,
that runs hourly, even when you are not logged in, and keeps one current:

- With a keytab, it gets a new ticket every hour, indefinitely. Run
  `siue-keytab` once to make the keytab: it asks for your campus password,
  checks it against the domain controller, and saves the derived keys in
  `/var/kerberos/krb5/user/<uid>/client.keytab` (readable only by you).
- Without one, it renews the current ticket, which works for up to 7 days
  after your last `kinit <campus-username>@CAMPUS.SIUE.EDU`.

**After every campus password change, run `siue-keytab` again.** The old
keytab stops working immediately; the timer falls back to renewing until you
do, which gives you up to 7 days.

The keytab can log in as you just as your password can. It is safe only on
a machine where nobody else has root.

A job sent without a valid ticket waits in the queue as "held for
authentication". Check the timer with
`journalctl --user -u siue-krb-refresh`.

### Sharing with Windows

Each PC you list may print to an `<queue>-win` twin of every queue, and those
jobs reach the print server under *your* campus login and account ID. Only
list your own machines. Only those addresses can reach the queues, through
both CUPS and the firewall, and the queues are not advertised. Rerunning the
playbook with a shorter list removes the dropped PCs' firewall rules; with an
empty list it also removes the shared queues and stops CUPS listening on the
network.

On the Windows PC: Settings → Bluetooth & devices → Printers & scanners →
Add device → **Add manually** → **Select a shared printer by name**, and enter

```text
http://<linux-host>:631/printers/ENG2ndFloorKyocera-win
http://<linux-host>:631/printers/ENG3rdFloorKyocera-win
```

where `<linux-host>` is the Linux machine's name (`hostname -f`). Accept the
Microsoft IPP Class Driver Windows offers. The Linux machine runs the
Kyocera driver and adds the account ID, so Windows needs neither.

## Configuration

### Inventory
The `inventories/local.yml` file is configured for local execution. Modify it or create a new one
to target remote hosts if needed.

### Role Variables

Each role has configurable variables in their respective `defaults/main.yml` files.

## License

This project is licensed under the MIT License: see the [LICENSE](LICENSE) file for details.
