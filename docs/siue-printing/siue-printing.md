---
title: "SIUE Copier Printing on Fedora"
subtitle:
  "Engineering Kyocera copiers through the campus print server, with Kerberos and job accounting"
author: "William Grim"
show_date: true
---

This guide sets up a Fedora machine to print to the Engineering Kyocera copiers through SIUE's
Windows print server, using your own campus login and copier account ID. Optionally, the same
machine can act as a print server for your own Windows PC.

# How it fits together

Each job is rendered on the Linux machine by Kyocera's own driver, which writes your copier account
ID into it. CUPS then hands it to `\\kyocera.campus.siue.edu` through the Windows Print Spooler
interface, the same way Windows clients submit jobs, authenticated with your Kerberos ticket, so no
password is stored anywhere. The print server queues are _RAW_: they pass jobs to the copier
unchanged.

| Local queue          | Copier         | Print-server queue           |
| -------------------- | -------------- | ---------------------------- |
| `ENG2ndFloorKyocera` | TASKalfa 6003i | `ENG2ndFloorKyoceraCopyRoom` |
| `ENG3rdFloorKyocera` | TASKalfa 7003i | `ENG3rdFloorKyoceraCopyRoom` |

> **Always use `kyocera.campus.siue.edu`.** The name `kyocera.isg.siue.edu` reaches the same
> machine, but only the `campus.siue.edu` name is registered in Active Directory, so Kerberos fails
> with the other one.

> **Why not Samba's `smb://` backend?** The print server refuses jobs written to the printer share
> over SMB, which is how Samba's `smbspool` prints. It does accept the Print Spooler calls Windows
> uses, so the `spoolss` backend below makes those.

# The quick way: Ansible

The `university` role in [the iac repository](https://github.com/happy-stl/iac) does everything in
this guide. The repository is public, so no GitHub account or invitation is needed to clone it. You
need Ansible, which Fedora packages:

```bash
sudo dnf install -y ansible git
git clone https://github.com/happy-stl/iac.git
cd iac
ansible-playbook -K playbooks/university.yml
siue-keytab
```

The playbook asks for everything personal, and keeps none of it in the repository. Press Enter to
accept a default:

| Prompt                    | Default               | Used for                                                    |
| ------------------------- | --------------------- | ----------------------------------------------------------- |
| CAMPUS username           | your Linux login name | Kerberos login to the print server                          |
| Kyocera copier account ID | none: required        | Written into every job as the copier's job-accounting code  |
| Windows PCs to share with | none                  | IPv4 addresses, comma-separated, that may print through you |

`siue-keytab` asks for your campus password once, so a ticket can be kept fresh for you (see
[Keep your ticket fresh](#keep-your-ticket-fresh)).

## Connecting a Windows PC with Ansible

If you shared the queues with a Windows PC, the same playbook can connect it: it trusts the Linux
machine's certificate on the PC and adds both copiers. Run it from the Linux print server, which
logs in to the PC with your Kerberos ticket, over WinRM on HTTPS.

**Once, on the PC**, in PowerShell run as Administrator. Use the PC's name in the campus domain and
your Linux machine's IP address:

```powershell
$fqdn  = '<pc-name>.campus.siue.edu'
$linux = '<linux-ip>'
Enable-PSRemoting -Force
$cert = New-SelfSignedCertificate -DnsName $fqdn, $env:COMPUTERNAME `
          -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(10)
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * `
  -CertificateThumbPrint $cert.Thumbprint -Force
New-NetFirewallRule -Name 'WINRM-HTTPS-In-TCP-SIUE' -DisplayName 'WinRM over HTTPS (Ansible)' `
  -Direction Inbound -Protocol TCP -LocalPort 5986 -RemoteAddress $linux -Action Allow
Disable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP*'
```

These settings survive restarts, and the PC's WinRM certificate lasts ten years. Run them again only
if the PC is reinstalled or renamed. If the Linux machine's IP address changes, update the rule:
`Set-NetFirewallRule -Name 'WINRM-HTTPS-In-TCP-SIUE' -RemoteAddress <new-linux-ip>`.

**Once, on the Linux machine**, install the WinRM client and describe the PC in an inventory file of
your own, outside the repository (here `~/.config/siue/windows.yml`). The repository has a copy to
start from, `inventories/siue-windows.example.yml`, or write it in one step:

```bash
sudo dnf install -y python3-winrm python3-requests-kerberos python3-kerberos
mkdir -p ~/.config/siue
cat > ~/.config/siue/windows.yml <<'EOF'
all:
  children:
    windows_dev:
      hosts:
        <pc-name>.campus.siue.edu:
          ansible_connection: winrm
          ansible_port: 5986
          ansible_winrm_scheme: https
          ansible_winrm_transport: kerberos
          ansible_winrm_server_cert_validation: ignore
          ansible_user: <campus-username>@CAMPUS.SIUE.EDU
          ansible_become: false
EOF
```

The PC's certificate is self-signed, so Ansible does not check it against a trusted root. Kerberos
still authenticates both ends, and the session is bound to the TLS channel.

**Then, and whenever the Linux machine's certificate changes:**

```bash
ansible-playbook -i inventories/local.yml -i ~/.config/siue/windows.yml \
  playbooks/university.yml --limit windows_dev
```

The rest of this guide is the same setup done by hand.

# Before you start

You need a Fedora machine on the campus network, a CAMPUS account, sudo, and your copier account ID.
Set these once in the shell you will run the steps from:

```bash
CAMPUS_USER=<campus-username>   # your CAMPUS login, without "CAMPUS\"
ACCT=<account-id>               # your Kyocera copier account ID (1-8 digits)
WINPC=<windows-pc-ip>           # only for Windows sharing: your PC's IPv4 address
```

Your Linux login name comes from `$USER`, which the shell already sets. Several steps download files
from the iac repository:

```bash
IAC=https://raw.githubusercontent.com/happy-stl/iac/main/roles
```

# Set up printing on Linux

## 1. Install the packages

`python3-samba` provides the Print Spooler client the backend uses. Kyocera's driver needs
`python3-pypdf` even though its RPM does not declare it; without it every job comes out empty.

```bash
sudo dnf install -y cups python3-samba samba-client krb5-workstation python3-pypdf
```

## 2. Point Kerberos at the campus realm

```bash
sudo tee /etc/krb5.conf.d/campus-siue.conf >/dev/null <<'EOF'
[libdefaults]
    default_realm = CAMPUS.SIUE.EDU
    dns_lookup_kdc = true
    dns_lookup_realm = true
    renew_lifetime = 7d

[domain_realm]
    .campus.siue.edu = CAMPUS.SIUE.EDU
    campus.siue.edu = CAMPUS.SIUE.EDU
    .isg.siue.edu = CAMPUS.SIUE.EDU
    isg.siue.edu = CAMPUS.SIUE.EDU
    .siue.edu = CAMPUS.SIUE.EDU
    siue.edu = CAMPUS.SIUE.EDU
EOF
```

## 3. Get a ticket and check you can see the print server

The list should include both copier queues.

```bash
kinit "$CAMPUS_USER@CAMPUS.SIUE.EDU"
smbclient -L //kyocera.campus.siue.edu --use-kerberos=required | grep ENG
```

## 4. Install Kyocera's Linux driver

Download the bundle, check its checksum, install only the Fedora RPM from it, and delete the rest.
The RPM's install script leaves its data directory world-writable, so the `chmod` puts that right.

```bash
D=$(mktemp -d) && cd "$D"
curl -L -o KyoceraLinuxPackages.tar.gz \
  https://www.kyoceradocumentsolutions.us/content/dam/download-center-americas-cf/us/drivers/drivers/KyoceraLinuxPackages_20240521_tar_gz.download.gz
echo "14235a8e4dbe9f2fdff481252e2cc64431f59a7dcf2497ef54852fb30211568f  KyoceraLinuxPackages.tar.gz" | sha256sum -c
tar -xzf KyoceraLinuxPackages.tar.gz Fedora/Global/kyodialog_x86_64/kyodialog-10.1-0.x86_64.rpm
sudo dnf install -y ./Fedora/Global/kyodialog_x86_64/kyodialog-10.1-0.x86_64.rpm
sudo chmod 755 /usr/share/kyocera10.1
cd && rm -rf "$D"
```

## 5. Install the Print Spooler backend

CUPS runs a backend as root when its mode is `0700`. This one then switches to the user who
submitted the job and prints with that user's Kerberos ticket.

```bash
curl -fsSL "$IAC/siue-printing/files/spoolss-backend.py" |
  sudo install -o root -g root -m 0700 /dev/stdin /usr/lib/cups/backend/spoolss
```

## 6. Start CUPS at boot

```bash
sudo systemctl enable --now cups
```

## 7. Create the two queues

`auth-info-required=negotiate` tells CUPS to pass the submitting user to the backend.

```bash
PPD=/usr/share/kyocera10.1/ppd10.1

sudo lpadmin -p ENG2ndFloorKyocera -E \
  -v spoolss://kyocera.campus.siue.edu/ENG2ndFloorKyoceraCopyRoom \
  -P $PPD/Kyocera_TASKalfa_6003i.ppd \
  -D "Kyocera TASKalfa 6003i - Engineering 2nd floor copy room" \
  -L "EB 2nd floor copy room" \
  -o auth-info-required=negotiate -o printer-is-shared=false

sudo lpadmin -p ENG3rdFloorKyocera -E \
  -v spoolss://kyocera.campus.siue.edu/ENG3rdFloorKyoceraCopyRoom \
  -P $PPD/Kyocera_TASKalfa_7003i.ppd \
  -D "Kyocera TASKalfa 7003i - Engineering 3rd floor copy room" \
  -L "EB 3rd floor copy room" \
  -o auth-info-required=negotiate -o printer-is-shared=false
```

CUPS warns that printer drivers are deprecated. The warning is expected and harmless.

## 8. Set your account ID

Do this after creating a queue: running `lpadmin -P` again replaces the queue's driver file and
clears the setting.

```bash
for q in ENG2ndFloorKyocera ENG3rdFloorKyocera; do
  sudo lpadmin -p $q -o KmManagment=Custom.$ACCT
done
```

## 9. Print a test page

```bash
lp -d ENG3rdFloorKyocera /usr/share/cups/data/testprint
lpstat -o        # empty again once the job has gone to the print server
```

# Keep your ticket fresh

A Kerberos ticket lasts about 10 hours. An hourly timer keeps one current, even when you are not
logged in, which the Windows queues depend on. With a _keytab_ (keys derived from your campus
password) it gets a new ticket every hour, indefinitely; without one it renews the current ticket,
which works for up to 7 days after your last `kinit`.

> **A keytab logs in as you, just as your password does.** Only make one on a machine where nobody
> else has root, and run `siue-keytab` again after every campus password change. Until you do, the
> old keytab is refused and the timer falls back to renewing, which leaves you up to 7 days.

## 1. Record your CAMPUS username and make the keytab folder

The folder is where Kerberos looks for your keytab by default.

```bash
mkdir -p ~/.config/siue ~/.config/systemd/user
echo "$CAMPUS_USER" > ~/.config/siue/campus-user
sudo install -d -m 0700 -o "$USER" -g "$(id -g)" /var/kerberos/krb5/user/$(id -u)
```

## 2. Install the two commands

`siue-krb-refresh` gets or renews the ticket. `siue-keytab` asks for your password, builds the
keytab in a temporary folder, and installs it only after a test login with it succeeds.

```bash
for cmd in siue-krb-refresh siue-keytab; do
  curl -fsSL "$IAC/siue-kerberos/templates/$cmd.j2" |
    sed -e 's/{{ siue_krb5_realm }}/CAMPUS.SIUE.EDU/' -e '/ansible_managed/d' |
    sudo install -o root -g root -m 0755 /dev/stdin /usr/local/bin/$cmd
done
```

## 3. Run it hourly, logged in or not

Lingering starts your user services at boot without a login session.

```bash
for unit in siue-krb-refresh.service siue-krb-refresh.timer; do
  curl -fsSL "$IAC/siue-kerberos/templates/$unit.j2" | sed '/ansible_managed/d' \
    > ~/.config/systemd/user/$unit
done
sudo loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now siue-krb-refresh.timer
```

## 4. Make your keytab

```bash
siue-keytab
```

# Share the queues with your Windows PC

This part is optional. Every job from the Windows PC reaches the print server under _your_ campus
login and your account ID, so share only with your own machines.

The shared queues are served over HTTPS only, and only to the PC's address. They are also advertised
on the network so Windows can list them; that announcement reaches every machine on the subnet,
which is why their names say whose share they are.

## 1. Add a backend that always prints as you

A job arriving over the network has no local user, so this wrapper tells the `spoolss` backend to
use your ticket.

```bash
sudo tee /usr/lib/cups/backend/spoolss-$USER >/dev/null <<EOF
#!/bin/sh
# CUPS backend: submit the job with $USER's Kerberos ticket, whoever sent it.
# Device URI: spoolss-$USER://<server>/<queue>
[ \$# -eq 0 ] && exit 0
export AUTH_UID=$(id -u)
export DEVICE_URI="spoolss://\${DEVICE_URI#spoolss-$USER://}"
exec /usr/lib/cups/backend/spoolss "\$@"
EOF
sudo chown root:root /usr/lib/cups/backend/spoolss-$USER
sudo chmod 0700 /usr/lib/cups/backend/spoolss-$USER
```

## 2. Create the shared twin queues

These take no login from Windows; the backend supplies yours. Their descriptions are what Windows
lists, so keep them short.

```bash
PPD=/usr/share/kyocera10.1/ppd10.1

sudo lpadmin -p ENG2ndFloorKyocera-win -E \
  -v spoolss-$USER://kyocera.campus.siue.edu/ENG2ndFloorKyoceraCopyRoom \
  -P $PPD/Kyocera_TASKalfa_6003i.ppd \
  -D "ENG 2nd Floor Copier ($USER's private share)" -L "EB 2nd floor copy room" \
  -o auth-info-required=none -o printer-is-shared=true

sudo lpadmin -p ENG3rdFloorKyocera-win -E \
  -v spoolss-$USER://kyocera.campus.siue.edu/ENG3rdFloorKyoceraCopyRoom \
  -P $PPD/Kyocera_TASKalfa_7003i.ppd \
  -D "ENG 3rd Floor Copier ($USER's private share)" -L "EB 3rd floor copy room" \
  -o auth-info-required=none -o printer-is-shared=true

for q in ENG2ndFloorKyocera-win ENG3rdFloorKyocera-win; do
  sudo lpadmin -p $q -o KmManagment=Custom.$ACCT
done
```

## 3. Make a certificate for HTTPS

Without one, CUPS makes a throwaway certificate that can change on restart, which would break the
trust you give it on Windows.

```bash
sudo dnf install -y openssl avahi
H=$(hostname -f); IP=$(hostname -I | awk '{print $1}')
sudo openssl req -x509 -newkey rsa:3072 -nodes -days 3650 \
  -keyout /etc/cups/ssl/$H.key -out /etc/cups/ssl/$H.crt -subj "/CN=$H" \
  -addext "subjectAltName=DNS:$H,DNS:$(hostname -s),IP:$IP" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth"
sudo chmod 0600 /etc/cups/ssl/$H.key
```

## 4. Open CUPS to the network, for one address, over HTTPS

Fedora normally starts CUPS on demand, listening only locally, and stops it after a minute idle.
`IdleExitTimeout 0` keeps it running so Windows can always reach it; `Encryption Required` refuses
plain HTTP on the shared queues.

```bash
sudo sed -i \
  -e 's/^Listen localhost:631$/Port 631/' \
  -e 's/^Browsing .*/Browsing Yes/' \
  -e 's/^BrowseLocalProtocols .*/BrowseLocalProtocols dnssd/' \
  -e 's/^IdleExitTimeout .*/IdleExitTimeout 0/' \
  /etc/cups/cupsd.conf

BLOCK=$(mktemp)
{
  echo "ServerAlias $(hostname -s) $(hostname -f) $(hostname -I | awk '{print $1}')"
  for q in ENG2ndFloorKyocera-win ENG3rdFloorKyocera-win; do
    printf '<Location /printers/%s>\n  Encryption Required\n  Order deny,allow\n  Deny from all\n  Allow from 127.0.0.1\n  Allow from %s\n</Location>\n' "$q" "$WINPC"
  done
} > "$BLOCK"
sudo sed -i "/^<Location \/>$/e cat $BLOCK" /etc/cups/cupsd.conf
rm "$BLOCK"

# The web pages (printers, queues, jobs) for the PC too, over HTTPS; /admin stays local
sudo sed -i "/^<Location \/>\$/,/^<\/Location>\$/c\\<Location />\n  Order allow,deny\n  Allow from $WINPC\n  Encryption Required\n</Location>" \
  /etc/cups/cupsd.conf

sudo systemctl enable --now avahi-daemon cups
sudo cupsd -t && sudo systemctl restart cups
```

> **Avoid `cupsctl` after this.** It rewrites `cupsd.conf` without comments. The settings survive,
> but the Ansible role marks its block with comments, and it removes the unmarked copy on its next
> run.

## 5. Allow that address through the firewall

```bash
sudo firewall-cmd --permanent \
  --add-rich-rule="rule family=\"ipv4\" source address=\"$WINPC/32\" port port=\"631\" protocol=\"tcp\" accept"
sudo firewall-cmd --reload
```

## 6. Check access

From this machine the first command should print `200`. The second asks through the machine's public
address, which stands in for any other campus computer, and should print `403`.

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:631/printers/ENG3rdFloorKyocera-win
curl -sk -o /dev/null -w '%{http_code}\n' \
  https://$(hostname -I | awk '{print $1}'):631/printers/ENG3rdFloorKyocera-win
```

# Connect the Windows PC

## 1. Trust the Linux machine's certificate

The Ansible play above does this step for you. By hand, first note the certificate's thumbprint on
the **Linux machine**:

```bash
openssl x509 -in /etc/cups/ssl/$(hostname -f).crt -noout -fingerprint -sha1 | sed 's/.*=//; s/://g'
```

Then, on the **Windows PC**, in PowerShell run as Administrator, fetch the certificate and compare:

```powershell
$h   = '<linux-host>'          # the Linux machine's name, from: hostname -f
$tcp = [Net.Sockets.TcpClient]::new($h, 631)
$ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false, { $true })
$ssl.AuthenticateAsClient($h)
$cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
$tcp.Close()
$cert.Thumbprint
```

Only if the two thumbprints match, trust it, then check that Windows now accepts the connection:

```powershell
$path = "$env:TEMP\$h.cer"
[IO.File]::WriteAllBytes($path, $cert.Export('Cert'))
Import-Certificate -FilePath $path -CertStoreLocation Cert:\LocalMachine\Root
Invoke-WebRequest -UseBasicParsing "https://${h}:631/printers/ENG3rdFloorKyocera-win" | Select-Object StatusCode
```

`StatusCode : 200` means the PC trusts the certificate. An error about a "trust relationship" means
the import did not take: it needs an Administrator PowerShell.

## 2. Add each printer by name

1. Open **Settings → Bluetooth & devices → Printers & scanners** and choose **Add device**.
2. Choose **Add manually**, then **Select a shared printer by name**, and enter the queue's address:

   ```text
   https://<linux-host>:631/printers/ENG2ndFloorKyocera-win
   https://<linux-host>:631/printers/ENG3rdFloorKyocera-win
   ```

3. When Windows asks for a driver, choose **Microsoft → Microsoft PS Class Driver**. Windows then
   sends PostScript, and the Linux machine renders it with the Kyocera driver and adds your account
   ID.

> **Use the address, not the discovery list.** The queues appear under Add device as "ENG 2nd Floor
> Copier (_user_'s private share)", but adding from that list stalls at "Connecting".

## 3. Print a test page

Your Windows print queue empties within a second or two even for a large job: it only holds a job
until the Linux machine has it. To follow a job from there, open `https://<linux-host>:631/` in a
browser on the PC (**Printers** and **Jobs**), or run `lpstat -o` on the Linux machine. Type the
`https://`: without it the browser tries plain HTTP first, and CUPS takes a second to redirect.

# Day to day

Nothing, as long as the timer has a working keytab. To see when your ticket expires and what the
timer last did:

```bash
klist
journalctl --user -u siue-krb-refresh -n 5
```

**After you change your campus password, run `siue-keytab`.** A job sent without a valid ticket
stays in the queue as _held for authentication_. Get a ticket, then release it:

```bash
siue-keytab               # or: kinit "$CAMPUS_USER@CAMPUS.SIUE.EDU"
lpstat -o                 # list waiting jobs
lp -i <job-id> -H resume
```

A job held with "could not be sent" is retried every 5 minutes. If it keeps failing, check the
copier itself: a status of `0x80` here means the print server cannot reach it (offline).

```bash
rpcclient --use-kerberos=required kyocera.campus.siue.edu \
  -c 'getprinter ENG2ndFloorKyoceraCopyRoom 2' | grep -E 'status|cjobs'
```

# What this installs and changes

| Item                                                   | Purpose                                                                                                         |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `cups`, `samba-client`, `krb5-workstation`             | Print system, SMB tools, and `kinit`/`klist`                                                                    |
| `python3-samba`                                        | Print Spooler client for the `spoolss` backend                                                                  |
| `python3-pypdf`                                        | Undeclared dependency of Kyocera's pre-filter                                                                   |
| `kyodialog-10.1`                                       | Kyocera driver, PPDs and filters; also a status daemon (`knmd`) at login                                        |
| `/etc/krb5.conf.d/campus-siue.conf`                    | Campus realm settings                                                                                           |
| `/usr/lib/cups/backend/spoolss`                        | Submits jobs through the Print Spooler interface                                                                |
| `ENG2ndFloorKyocera`, `ENG3rdFloorKyocera`             | Local queues, printing as whoever submits the job                                                               |
| `cups.service` enabled                                 | CUPS runs from boot                                                                                             |
| `/usr/local/bin/siue-keytab`, `siue-krb-refresh`       | Make the keytab; refresh the ticket                                                                             |
| `siue-krb-refresh.timer` (user unit), lingering on     | Hourly ticket refresh, with or without a login                                                                  |
| `~/.config/siue/campus-user`                           | Your CAMPUS username, for the two commands                                                                      |
| `/var/kerberos/krb5/user/<uid>/client.keytab`          | Your keytab, mode 0600                                                                                          |
| **Windows sharing only**                               |                                                                                                                 |
| `/usr/lib/cups/backend/spoolss-<user>`                 | Prints with your ticket for network jobs                                                                        |
| `ENG2ndFloorKyocera-win`, `ENG3rdFloorKyocera-win`     | Shared queues                                                                                                   |
| `/etc/cups/ssl/<host>.crt`, `.key`                     | Long-lived certificate for HTTPS                                                                                |
| `/etc/cups/cupsd.conf`                                 | Network listener, advertising, never idles out, HTTPS-only access for the PC to the shared queues and web pages |
| `avahi`, `openssl`; `avahi-daemon` enabled             | Advertising, and making the certificate                                                                         |
| firewalld rich rule                                    | TCP 631 from the Windows PC only                                                                                |
| `/etc/cups/siue-print-share-clients`                   | (Ansible only) The PCs the firewall was opened for, so a later run removes only its own rules                   |
| **Windows PC (Ansible play)**                          |                                                                                                                 |
| The Linux machine's certificate in `LocalMachine\Root` | Lets Windows trust the HTTPS printers                                                                           |
| `Microsoft PS Class Driver`                            | Driver for both printers                                                                                        |
| `ENG 2nd Floor Copier`, `ENG 3rd Floor Copier`         | Printers on Internet ports, `https://<linux-host>:631/printers/…-win`                                           |
