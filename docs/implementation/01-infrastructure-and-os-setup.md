# Infrastructure & OS Setup — Implementation

[Documentation index](../README.md) · [Approach](../approach/01-infrastructure-and-os-setup.md)

This runbook provisions both Debian 13 (Trixie) VMs, creates a dedicated LVM
logical volume for `/var/lib`, configures the `debian` administrator, hardens
SSH, installs the base OS and security packages, and installs Docker Engine.
Run every host step on both nodes unless it explicitly says otherwise.

## 1. Install Debian 13 from the ISO

Attach the Debian 13 (Trixie) minimal ISO and choose **Graphical install**.
Complete the installer as follows:

1. Enter the static address, prefix/netmask, gateway, and DNS server manually.
2. Set the node-specific hostname. Set a strong root password for the initial
   console bootstrap, then create the non-root user `debian` with its own strong
   password.
3. Choose **Guided - use entire disk and set up LVM** for the 10 GB OS disk.
4. Name the volume group `sepehrgv1` and keep `/` in LVM. Confirm the exact
   partition plan before writing it to disk.
5. In software selection, clear every desktop environment. Select only
   **standard system utilities** and **SSH server**.
6. Finish the installation, remove the ISO, reboot, and log in as `debian`.

The added data disk is configured after the first boot so it cannot be confused
with the installer target.

## 2. Configure package sources and administrator access

Become root for the initial setup because `sudo` is not installed yet:

```bash
su -
```

Review `/etc/apt/sources.list` and any files below `/etc/apt/sources.list.d/`.
Keep the installer-selected Debian mirror, `trixie`, `trixie-updates`, and
`trixie-security` entries. Do not define the same repository in both legacy
`.list` and deb822 `.sources` files.

```bash
vim /etc/apt/sources.list
apt update
apt install -y sudo vim
usermod -aG sudo debian
```

Edit the main `/etc/sudoers` file safely:

```bash
visudo -f /etc/sudoers
```

Add the following line:

```sudoers
%debian ALL=(ALL:ALL) NOPASSWD: ALL
```

The leading `%` applies the rule to the `debian` group. Validate the complete
sudoers configuration before leaving the root shell:

```bash
visudo -c
update-alternatives --config editor
exit
```

Select `vim.tiny` when prompted. Log out and back in so the new group membership
takes effect, then confirm `sudo -n true` succeeds.

## 3. Apply the initial OS baseline

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt autoclean
sudo apt install -y --no-install-recommends \
  ca-certificates curl fail2ban iptables iptables-persistent qemu-guest-agent \
  rsync systemd-timesyncd util-linux-extra
sudo timedatectl set-timezone Asia/Tehran
sudo systemctl enable --now systemd-timesyncd
sudo systemctl enable --now qemu-guest-agent
sudo apt autoremove --purge -y
```

Install `qemu-guest-agent` only on a QEMU/KVM-based VM. On another hypervisor,
use its supported guest agent instead. Verify the baseline:

```bash
cat /etc/os-release
timedatectl status
systemctl is-active systemd-timesyncd
systemctl is-active qemu-guest-agent
```

## 4. Create the `/var/lib` logical volume

Add the second 10 GB virtual disk to the powered-off VM, then boot and identify
it from the VM console. The example uses `/dev/sdb`; device names can differ.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL
sudo pvs
sudo vgs
sudo lvs
```

The following command destroys existing metadata on its target. Continue only
after proving that `/dev/sdb` is the empty added disk and is not mounted.

```bash
sudo pvcreate /dev/sdb
sudo vgextend sepehrgv1 /dev/sdb
sudo lvcreate -l 100%PVS -n var_lib sepehrgv1 /dev/sdb
sudo mkfs.ext4 /dev/sepehrgv1/var_lib
```

Using `100%PVS` with `/dev/sdb` keeps this logical volume on the added physical
volume. If the installed volume-group name is not `sepehrgv1`, use the exact
name reported by `sudo vgs`; do not guess between similar names.

Copy the existing data before Docker is installed:

```bash
sudo systemctl stop fail2ban
sudo mkdir -p /mnt/var_lib
sudo mount /dev/sepehrgv1/var_lib /mnt/var_lib
sudo rsync -aHAXx /var/lib/ /mnt/var_lib/
sudo blkid /dev/sepehrgv1/var_lib
```

Add an `/etc/fstab` entry using the UUID reported by `blkid`:

```fstab
UUID=REPLACE_WITH_REAL_UUID /var/lib ext4 defaults 0 2
```

Test the entry before rebooting:

```bash
sudo umount /mnt/var_lib
sudo systemctl daemon-reload
sudo mount /var/lib
findmnt /var/lib
df -hT / /var/lib
sudo reboot
```

After reconnecting, run `findmnt /var/lib` again. Do not install Docker until
the logical volume mounts automatically and the copied data is present.

## 5. Configure and harden SSH

Create the administrator's key file and add the supplied public key as one
unbroken line:

```bash
sudo install -d -m 0700 -o debian -g debian /home/debian/.ssh
sudo touch /home/debian/.ssh/authorized_keys
sudo chown debian:debian /home/debian/.ssh/authorized_keys
sudo chmod 0600 /home/debian/.ssh/authorized_keys
sudo vim /home/debian/.ssh/authorized_keys
```

Create the warning text in `/etc/ssh/banner`, protect it, then create
`/etc/ssh/sshd_config.d/99-project-hardening.conf`:

```bash
sudo vim /etc/ssh/banner
sudo chmod 0644 /etc/ssh/banner
sudo vim /etc/ssh/sshd_config.d/99-project-hardening.conf
```

```text
Port 8546
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

An RSA public key can use modern RSA-SHA2 signatures. Do not enable the obsolete
`ssh-rsa` signature algorithm unless a legacy client makes it unavoidable.

Before reloading SSH, allow TCP 8546 in both the upstream firewall and the host
firewall. Keep the current session open, validate the complete configuration,
reload Debian's `ssh` service, and test from a second terminal:

```bash
sudo sshd -t
sudo systemctl reload ssh
sudo ss -lntp | grep ':8546'
ssh -p 8546 debian@192.168.1.11
```

Confirm that key-only access works before removing the port 22 firewall rule.
Also verify that root login and password login fail.

## 6. Configure Fail2ban and the firewall

Create `/etc/fail2ban/jail.d/sshd.local`:

```ini
[sshd]
enabled = true
port = 8546
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

Build iptables rules from the VM console. At minimum, allow loopback,
established traffic, TCP 8546, HTTP, and VRRP protocol 112 only between the two
nodes before setting the default input policy to drop. Docker adds its own rules;
after Docker is installed, enforce container restrictions in the `DOCKER-USER`
chain as well. Persist only a ruleset that has passed a second-session access
test:

```bash
sudo netfilter-persistent save
```

## 7. Configure key replication from Node 1

The repository provides:

- `ssh-key-sync/ssh-key-sync.sh`
- `ssh-key-sync/ssh-key-sync.service`
- `ssh-key-sync/ssh-key-sync.path`

Before installing them, normalize the source and destination user, file paths,
`User=`, `Group=`, destination address, and SSH port 8546. Node 1 also needs a
dedicated non-interactive identity that remains trusted when the operator's
login key changes. Do not store that automation credential in the
`authorized_keys` file being replaced.

Install the normalized files on Node 1:

```bash
sudo install -m 0750 ssh-key-sync/ssh-key-sync.sh /usr/local/bin/sync-ssh-key.sh
sudo install -m 0644 ssh-key-sync/ssh-key-sync.service /etc/systemd/system/
sudo install -m 0644 ssh-key-sync/ssh-key-sync.path /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ssh-key-sync.path
```

Verify Node 2's host key, test the sync manually, change Node 1's managed key,
and inspect the service result:

```bash
sudo systemctl start ssh-key-sync.service
sudo systemctl status ssh-key-sync.service --no-pager
sudo journalctl -u ssh-key-sync.service -n 50 --no-pager
```

## 8. Install Docker Engine

Use Docker's official Debian repository:

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Add `/etc/apt/sources.list.d/docker.sources`:

```text
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
```

If the VM is not `amd64`, replace the architecture with the value from
`dpkg --print-architecture`. Install and verify the packages:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker debian
sudo docker run --rm hello-world
sudo docker version
sudo docker compose version
```

The `docker` group is root-equivalent. Log out and back in before testing Docker
without `sudo`.

## Acceptance checks

- Both nodes boot Debian 13 without an emergency-mode or mount error.
- Each node uses the recorded static address, gateway, and DNS server.
- `/` is on the installer-created LVM and `/var/lib` is on the 10 GB added disk.
- The `debian` user has the validated passwordless sudo rule.
- SSH listens on TCP 8546; key login succeeds while root and password login fail.
- The SSH banner appears and Fail2ban monitors port 8546.
- Changing the managed key on Node 1 updates Node 2 and logs a successful unit.
- The firewall survives reboot and still permits SSH, HTTP, and required VRRP.
- Tehran time, time synchronization, and the appropriate guest agent are active.
- Docker starts on boot, stores its state beneath the `/var/lib` mount, and the
  operator can run Docker Compose.

## References

- [Debian 13 (Trixie) installation guide](https://www.debian.org/releases/trixie/installmanual)
- [Debian Trixie `sshd_config` manual](https://manpages.debian.org/trixie/openssh-server/sshd_config.5.en.html)
- [Docker Engine installation on Debian](https://docs.docker.com/engine/install/debian/)
