# Infrastructure and OS Initial

This runbook provisions both Debian 13 (Trixie) VMs, creates a dedicated LVM
logical volume for `/var/lib`, configures the `debian` administrator and SSH
access, installs the base OS packages, and installs Docker Engine.
Run every host step on both nodes unless it explicitly says otherwise.

## 1. Install Debian 13 from the ISO

Reference: [Debian 13 installation guide](https://www.debian.org/releases/trixie/installmanual)

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

## 2. Configure package sources

Become root for the initial setup because `sudo` is not installed yet:

```bash
su -
```

Replace the contents of `/etc/apt/sources.list` with:

```bash
vim /etc/apt/sources.list
```

```sources.list
# Main Debian repository
deb http://deb.debian.org/debian/ trixie main contrib non-free-firmware
deb-src http://deb.debian.org/debian/ trixie main contrib non-free-firmware

# Security updates
deb http://security.debian.org/debian-security trixie-security main contrib non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main contrib non-free-firmware

# Updates (formerly known as 'volatile')
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free-firmware
deb-src http://deb.debian.org/debian/ trixie-updates main contrib non-free-firmware
```

```bash
apt update
```

## 3. OS Initial

```bash
apt update && apt install -y sudo vim rsync curl
sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean
sudo timedatectl set-timezone Asia/Tehran
sudo systemctl enable --now systemd-timesyncd
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
sudo apt autoremove --purge -y
usermod -aG sudo debian
```

`qemu-guest-agent` is installed so the QEMU/KVM hypervisor can communicate with
the VM for operations such as clean shutdown, status reporting, and IP address
discovery.

Edit the main `/etc/sudoers` file safely with `visudo`:

```bash
visudo /etc/sudoers
```

Add the following line:

```sudoers
%debian ALL=(ALL:ALL) NOPASSWD: ALL
```

Set the default editor:

```bash
update-alternatives --config editor
```

This step is optional. I personally prefer Vim, so I select `vim.tiny` when
prompted.

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

## 5. Configure SSH access

Run `ssh-keygen` as the `debian` user to create the `.ssh` directory with its
default permissions, then add the supplied public key to `authorized_keys` as
one unbroken line:

```bash
ssh-keygen
vim ~/.ssh/authorized_keys
```

## 6. Configure key replication from Node 1

The repository provides:

- `ssh-key-sync/ssh-key-sync.sh`
- `ssh-key-sync/ssh-key-sync.service`
- `ssh-key-sync/ssh-key-sync.path`

The service uses `User=debian` and `Group=debian`. The path unit watches
`/home/debian/.ssh/authorized_keys`.

Copy the files on Node 1:

```bash
sudo chmod +x ssh-key-sync/ssh-key-sync.sh
sudo cp ssh-key-sync/ssh-key-sync.sh /usr/local/bin/sync-ssh-key.sh
sudo cp ssh-key-sync/ssh-key-sync.service /etc/systemd/system/
sudo cp ssh-key-sync/ssh-key-sync.path /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ssh-key-sync.path
```

## 7. Install Docker Engine

Reference: [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/#install-using-the-repository)

Add Docker's official GPG key:

```bash
sudo apt update
sudo apt install ca-certificates
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Add the Docker repository to Apt sources:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

Install Docker Engine:

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Docker post-install

Reference: [Linux post-installation steps for Docker Engine](https://docs.docker.com/engine/install/linux-postinstall/)

```bash
sudo usermod -aG docker $USER
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```
