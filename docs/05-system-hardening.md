# System Hardening

Apply the following hardening steps on both nodes.

## 1. Harden SSH

Reference: [SSH hardening best practices](https://linuxize.com/post/ssh-hardening-best-practices/)

Create the SSH banner:

```bash
sudo vim /etc/ssh/banner
```

For example, use the following warning message:

```text
Authorized access only. All activity is monitored and logged.
```

Edit the SSH daemon configuration:

```bash
sudo vim /etc/ssh/sshd_config
```

Choose a non-default SSH port and replace `<SSH_PORT>` with that port:

These are the SSH hardening options I prefer to use:

```text
Port <SSH_PORT>
PermitRootLogin no
PermitEmptyPasswords no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
LoginGraceTime 30
MaxAuthTries 3
X11Forwarding no
Banner /etc/ssh/banner
```

Restart the SSH daemon to apply the new configuration. Keep the current SSH
session open until a new connection succeeds with the selected port and key.

```bash
sudo systemctl restart sshd
```

## 2. Configure Fail2ban

Install Fail2ban:

```bash
sudo apt install fail2ban
sudo systemctl enable --now fail2ban
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

Restart Fail2ban to apply the SSH jail configuration, then verify its status:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## 3. Install iptables

References:

- [ArchWiki: Iptables](https://wiki.archlinux.org/title/Iptables#)
- [ArchWiki: Simple stateful firewall](https://wiki.archlinux.org/title/Simple_stateful_firewall)
- [Docker with iptables](https://docs.docker.com/engine/network/firewall-iptables/)

Install iptables and its persistence service, then enable the service at boot:

```bash
sudo apt install -y iptables iptables-persistent
sudo systemctl enable netfilter-persistent
```

## 4. Configure persistent iptables rules

The following is the persistent IPv4 ruleset for Node 1. Replace
`<SSH_PORT>`, `<NODE_1_IP>`, and `<NODE_2_IP>` with the deployment values. It
allows established traffic, loopback, HTTP, SSH on the selected non-default
port, and VRRP (IP protocol 112) from Node 2.

Save the active rules before editing so Docker-generated rules remain intact:

```bash
sudo iptables-save /etc/iptables/rules.v4
```

Edit `/etc/iptables/rules.v4` and add the required custom rules to their
corresponding existing `raw` and `filter` tables. The following block shows
where the rules belong; do not copy and paste it over the complete file.
Preserve the Docker-generated runtime rules already in the file, replace every
placeholder with the correct deployment value, and place new rules before the
`COMMIT` line for the relevant table.

```iptables
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
# ===========================
# INPUT
# ===========================
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport <SSH_PORT> -j ACCEPT
-A INPUT -p 112 -s <NODE_2_IP> -j ACCEPT
# ===========================
# OUTPUT
# ===========================
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -p udp --dport 53 -j ACCEPT
-A OUTPUT -p tcp --dport 53 -j ACCEPT
-A OUTPUT -p tcp --dport 80 -j ACCEPT
-A OUTPUT -p tcp --dport 443 -j ACCEPT
-A OUTPUT -p 112 -s <NODE_1_IP> -j ACCEPT
# ===========================
# DOCKER
# ===========================
-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -s 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -j ACCEPT
-A DOCKER-USER -p tcp -m conntrack --ctorigdstport 80 --ctdir ORIGINAL -j ACCEPT
-A DOCKER-USER -p tcp -m conntrack --ctorigdstport 443 --ctdir ORIGINAL -j ACCEPT
-A DOCKER-USER -j RETURN
-A DOCKER-USER -j DROP
# ===========================
COMMIT
```

I intentionally kept the `OUTPUT` policy set to `ACCEPT` because I did not
consider blocking outbound traffic necessary for this deployment. The explicit
DNS, HTTP, HTTPS, loopback, and VRRP allow rules document the outbound traffic
the system depends on. They also prepare the ruleset for possible future
outbound `DROP` or `REJECT` rules without causing essential services to stop
working.

I implemented the `DOCKER-USER` rules with help from ChatGPT and a friend.
Managing Docker's interaction with iptables proved challenging, so I chose
this approach as a simpler and more manageable solution for this deployment.

Validate the file, restore it, and verify the active rules:

```bash
sudo iptables-restore --test /etc/iptables/rules.v4
sudo iptables-restore < /etc/iptables/rules.v4
sudo systemctl restart docker
```

Docker is restarted intentionally so it recreates its Docker-managed chains and
rules in the active runtime ruleset. Docker creates these rules for bridge
networks, forwarding, masquerading, and published container ports, as described
in the [Docker with iptables documentation](https://docs.docker.com/engine/network/firewall-iptables/).
