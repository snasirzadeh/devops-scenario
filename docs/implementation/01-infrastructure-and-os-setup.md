# Infrastructure & OS Setup — Implementation

[Documentation index](../README.md) · [Approach](../approach/01-infrastructure-and-os-setup.md)

This runbook provisions two Debian-family Linux VMs, mounts the second disk at
`/var/lib`, creates a sudo-enabled non-root operator, locks SSH to public-key
authentication, installs the base security controls, and installs Docker Engine.
Run host configuration on both nodes unless a step says otherwise.

## 1. Record the environment

Use the same choices throughout the repository. The examples assume:

| Setting | Node 1 | Node 2 |
|---|---:|---:|
| Hostname | `server1` | `server2` |
| Address | `192.168.1.11` | `192.168.1.12` |
| OS disk | 10 GB, mounted at `/` | 10 GB, mounted at `/` |
| Data disk | 20 GB, mounted at `/var/lib` | 20 GB, mounted at `/var/lib` |
| Operator | `debian` | `debian` |

Reserve `192.168.1.10` for the virtual IP used in section 5. Replace device
names, addresses, user names, and interface names with the actual inventory.

## 2. Install the OS and mount the data disk

The safest method is to assign the mount points in the OS installer: put `/` on
the 10 GB disk and `/var/lib` on an ext4 filesystem on the 20 GB disk. If the OS
is already installed, first identify the unused disk:

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,UUID
findmnt /
findmnt /var/lib
```

Do not copy the following example blindly: formatting the wrong device destroys
its data. From a console session, format the verified empty data partition,
temporarily mount it, stop services that write under `/var/lib`, copy existing
content while preserving ownership, then add the filesystem UUID to `/etc/fstab`.

```bash
sudo mkfs.ext4 /dev/sdb1
sudo mkdir -p /mnt/new-var-lib
sudo mount /dev/sdb1 /mnt/new-var-lib
sudo rsync -aHAXx /var/lib/ /mnt/new-var-lib/
sudo blkid /dev/sdb1
```

Add an entry using the UUID reported by `blkid`:

```fstab
UUID=REPLACE_WITH_REAL_UUID /var/lib ext4 defaults,nofail 0 2
```

Reboot during a maintenance window, then verify before installing Docker:

```bash
findmnt /var/lib
df -hT / /var/lib
```

## 3. Create the non-root operator

```bash
sudo adduser debian
sudo usermod -aG sudo debian
sudo install -d -m 700 -o debian -g debian /home/debian/.ssh
sudo install -m 600 -o debian -g debian /dev/null /home/debian/.ssh/authorized_keys
```

Put the supplied public key on one line in `authorized_keys`. Confirm a second
SSH session works before hardening the daemon.

Create `/etc/ssh/sshd_config.d/99-project-hardening.conf`:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers debian
MaxAuthTries 3
X11Forwarding no
AllowTcpForwarding no
```

An RSA public key can still use modern RSA-SHA2 signatures. Do not enable the
obsolete `ssh-rsa` signature algorithm unless an old client makes it unavoidable.

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Keep the original administrative session open until a new key-only session is
confirmed.

## 4. Configure key replication from Node 1

The repository provides:

- `ssh-key-sync/ssh-key-sync.sh`
- `ssh-key-sync/ssh-key-sync.service`
- `ssh-key-sync/ssh-key-sync.path`

Before installing them, normalize the source and destination user, file paths,
`User=`, `Group=`, and the `server2` SSH target. Node 1 also needs a dedicated
non-interactive SSH identity that Node 2 will continue to trust when the user's
login key changes. Keep that automation credential separate from the
`authorized_keys` file being replaced.

Install the normalized files on Node 1:

```bash
sudo install -m 0750 ssh-key-sync/ssh-key-sync.sh /usr/local/bin/sync-ssh-key.sh
sudo install -m 0644 ssh-key-sync/ssh-key-sync.service /etc/systemd/system/
sudo install -m 0644 ssh-key-sync/ssh-key-sync.path /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ssh-key-sync.path
```

Verify the destination host key in `known_hosts`, test the sync script manually,
then update Node 1's managed key and inspect Node 2:

```bash
sudo systemctl start ssh-key-sync.service
sudo systemctl status ssh-key-sync.service --no-pager
sudo journalctl -u ssh-key-sync.service -n 50 --no-pager
```

## 5. Apply baseline hardening

Install security packages:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl fail2ban iptables iptables-persistent rsync unattended-upgrades
sudo systemctl enable --now fail2ban
```

Create `/etc/fail2ban/jail.d/sshd.local`:

```ini
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
```

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

Build firewall rules from the VM console so a mistake cannot strand the host.
At minimum, allow loopback, established traffic, SSH, HTTP, and VRRP protocol 112
between the two nodes before applying a default-drop policy. Docker manages its
own chains; enforce container ingress restrictions in `DOCKER-USER` as well as
the host `INPUT` chain. Save the verified rules with:

```bash
sudo netfilter-persistent save
```

Enable automatic security upgrades according to the maintenance policy and
verify that time synchronization is active:

```bash
sudo dpkg-reconfigure -plow unattended-upgrades
timedatectl status
```

## 6. Install Docker Engine

Follow Docker's official repository procedure for the installed distribution,
then install Engine, Buildx, and the Compose plugin. The resulting packages are
normally `docker-ce`, `docker-ce-cli`, `containerd.io`,
`docker-buildx-plugin`, and `docker-compose-plugin`.

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker debian
```

Membership in the `docker` group is root-equivalent. Grant it only to the
operator responsible for this deployment, then log out and back in.

```bash
docker version
docker compose version
docker run --rm hello-world
```

## Acceptance checks

- Both nodes boot without an emergency-mode or mount error.
- `/` is on the 10 GB disk and `/var/lib` is on the 20 GB disk.
- The non-root user can use `sudo`; direct root and password SSH logins fail.
- Changing the managed key on Node 1 updates Node 2 and logs a successful unit.
- Fail2ban is monitoring SSH and the saved firewall survives a reboot.
- Docker starts on boot and the operator can run Compose.
