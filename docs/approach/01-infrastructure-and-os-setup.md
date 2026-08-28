# Infrastructure & OS Setup — Approach

## Goal

Build two replaceable Debian 13 (Trixie) virtual machines with the same minimal
OS installation, LVM layout, static network configuration, access controls,
security baseline, and Docker runtime. The two-node design removes the web host
as a single point of failure while remaining small enough to operate without a
cluster orchestrator.

## Topology

```text
                              virtual IP
                                  |
                  +---------------+---------------+
                  |                               |
            Node 1 (preferred)               Node 2 (backup)
            static address                   static address
            10 GB OS disk                    10 GB OS disk
            10 GB /var/lib disk              10 GB /var/lib disk
            Debian 13 + Docker               Debian 13 + Docker
                  |
                  +---- authorized-key sync ---->
```

Both nodes are configured alike except for hostname, IP address, and
high-availability priority. This symmetry makes failover easier to understand
and prevents one server from depending on undocumented local state.

## Design choices

### Two independent VMs

Separate VMs isolate an OS shutdown and allow Keepalived to move service
ownership. A second container on the same VM would protect only against a
container failure, not an OS or VM failure.

Two nodes are sufficient for active/passive VRRP but do not provide quorum.
Reliable Layer 2 connectivity, restricted VRRP traffic, and failover testing are
therefore necessary to reduce split-brain risk.

### Minimal Debian 13 (Trixie)

The machines use the Debian 13 ISO and the graphical installer, but no desktop
environment is installed. Only the standard system utilities and OpenSSH server
tasks are selected. This provides the packages needed for administration while
keeping the running service set and patch surface small.

Static address, gateway, and DNS values are entered during installation so the
servers do not depend on a changing DHCP lease. The values must be recorded in
the environment inventory before either VM is built.

### LVM for the root and data volumes

The installer places the 10 GB OS disk in the `sepehrgv1` volume group. A second
10 GB virtual disk is then added to that volume group and allocated to a
dedicated `var_lib` logical volume mounted at `/var/lib`.

Docker normally stores images, layers, volumes, and container metadata below
`/var/lib/docker`. Separating `/var/lib` limits the effect of Docker growth on
the root filesystem and makes its capacity visible. The logical volume must be
explicitly allocated from the second physical volume; otherwise LVM may place
extents on another disk with free space.

This layout is capacity management, not a backup. Failure of the data disk still
loses Docker state, and application content must be backed up or replicated
separately.

### Named administrator with passwordless sudo

The installer creates the `debian` account with a strong local password. A
dedicated sudoers entry permits that user to run administrative commands without
another password prompt, matching the recorded installation. This is convenient
for automation, but it also means compromise of the account immediately grants
root access. The sudoers file must be mode `0440`, validated with `visudo`, and
limited to this administrative account.

Remote access is stricter than console access: SSH listens on TCP 8546, rejects
root and password logins, accepts only public keys, and displays a login banner.
Moving SSH off port 22 reduces background scanning noise but is not an
authentication control; key-only authentication and firewall policy provide the
real protection.

The `docker` group is also root-equivalent because members can ask the daemon to
mount or modify host resources. Membership must be as narrow as sudo access.

### Event-driven key synchronization

A systemd path unit watches Node 1's managed `authorized_keys` file and triggers
a oneshot service to copy updates to Node 2. A separate automation identity is
required so replacing the operator's login key does not remove the credential
needed to perform the next synchronization.

For more than two nodes, configuration management or an SSH certificate
authority is a better fit. Point-to-point file replication scales poorly and
can propagate accidental deletion.

### Layered host hardening

The controls address different risks:

- OpenSSH configuration limits authentication attempts and disables unnecessary
  remote features.
- Iptables limits reachable services and permits VRRP only between the two
  nodes.
- Fail2ban watches the SSH journal and temporarily blocks repeated failures on
  port 8546.
- Package upgrades shorten exposure to known vulnerabilities.
- `systemd-timesyncd` keeps timestamps useful for logs and incident analysis.
- `qemu-guest-agent` gives the hypervisor a controlled channel for VM lifecycle
  operations.

Docker programs iptables rules of its own. Container ingress restrictions must
also be enforced in the `DOCKER-USER` chain and retested after Docker restarts.

### Docker packages from Docker's repository

Docker Engine, the CLI, containerd, Buildx, and the Compose plugin are installed
from Docker's signed Debian repository. This keeps the components compatible
and provides a supported Debian 13 package path. Repository configuration and
package origin must be rechecked during OS upgrades.

## Rejected alternatives

- **Password-based SSH:** easy to bootstrap, but exposes reusable credentials to
  brute-force and credential-reuse attacks.
- **One root filesystem:** requires fewer setup steps, but Docker growth can
  exhaust the OS filesystem.
- **Manual key copying:** works once, but does not meet the automatic update
  requirement and drifts easily.
- **Kubernetes or another orchestrator:** adds control-plane and operational
  complexity that is unnecessary for one static service on two VMs.

## Risks and controls

| Risk | Control |
|---|---|
| Wrong disk initialized as an LVM PV | Verify device name, serial, size, filesystems, and mounts from the VM console before `pvcreate` |
| `/var/lib` migration loses or omits data | Perform it before Docker is installed, use `rsync -aHAX`, mount by UUID, and verify after reboot |
| SSH lockout | Open TCP 8546 first, validate with `sshd -t`, and test a second key-only session before closing the first |
| Passwordless sudo increases impact of account compromise | Restrict the entry to `debian`, protect SSH keys, and review access regularly |
| Key sync removes its own access | Use a separate automation identity and test repeated key changes |
| Firewall breaks Docker or VRRP | Allow required traffic first, test from the console, and persist only verified rules |
| `/var/lib` fills | Monitor filesystem usage and prune only under an explicit retention policy |

## References

- [Debian 13 (Trixie) installation guide](https://www.debian.org/releases/trixie/installmanual)
- [Debian Trixie `sshd_config` manual](https://manpages.debian.org/trixie/openssh-server/sshd_config.5.en.html)
- [Docker Engine installation on Debian](https://docs.docker.com/engine/install/debian/)
