# System Hardening — Implementation

Apply the following hardening steps on both nodes.

## 1. Harden SSH

Create the SSH banner:

```bash
sudo vim /etc/ssh/banner
```

Edit the SSH daemon configuration:

```bash
sudo vim /etc/ssh/sshd_config
```

Choose a non-default SSH port and replace `<SSH_PORT>` with that port:

```text
Port <SSH_PORT>
PermitRootLogin no
PermitEmptyPasswords no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers debian
LoginGraceTime 30
MaxAuthTries 3
X11Forwarding no
AllowTcpForwarding no
Banner /etc/ssh/banner
```

```bash
sudo systemctl restart sshd
```

## 2. Configure Fail2ban

Install Fail2ban:

```bash
sudo apt install fail2ban
```

Create `/etc/fail2ban/jail.d/sshd.local`:

```ini
[sshd]
enabled = true
port = <SSH_PORT>
filter = sshd
backend = systemd
maxretry = 3
findtime = 600
bantime = 3600
```

```bash
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## 3. Install iptables

```bash
sudo apt install -y iptables iptables-persistent
```

## Reference

- [Debian Trixie `sshd_config` manual](https://manpages.debian.org/trixie/openssh-server/sshd_config.5.en.html)
