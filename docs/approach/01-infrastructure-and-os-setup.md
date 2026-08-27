# Infrastructure & OS Setup — Approach

[Documentation index](../README.md) · [Implementation](../implementation/01-infrastructure-and-os-setup.md)

## Goal

Provide two replaceable Linux hosts with the same storage layout, access model,
security baseline, and container runtime. The two-node design removes the web
host as a single point of failure while keeping the lab small enough to operate
without a cluster orchestrator.

## Topology

```text
                         virtual IP
                             |
             +---------------+---------------+
             |                               |
       Node 1 (preferred)               Node 2 (backup)
       10 GB / + 20 GB /var/lib         10 GB / + 20 GB /var/lib
       Docker + Nginx                    Docker + Nginx
             |
             +---- authorized-key sync ------>
```

Both nodes are configured alike except for identity and high-availability
priority. Symmetry makes failover behavior easier to understand and recovery
less dependent on one machine's hidden state.

## Design choices

### Two independent VMs

Separate VMs isolate a host shutdown and let Keepalived move service ownership.
A second container on the same VM would protect only against a container
failure, not an OS or hypervisor-level failure.

Two nodes are sufficient for active/passive VRRP but do not provide quorum.
Network partition behavior therefore depends on reliable Layer 2 connectivity
and firewall rules; split-brain prevention must be tested.

### Debian stable as the reference OS

The repository's paths, service names, `apt` commands, and `debian` user examples
indicate a Debian-family environment. Debian stable provides predictable package
updates, systemd, Fail2ban, logrotate, and a small operational surface. The
runbooks can be adapted to Ubuntu, but package sources and defaults must be
validated rather than assumed identical.

### Separate `/var/lib` storage

Docker normally stores images, layers, and container metadata beneath
`/var/lib/docker`. Mounting the larger 20 GB disk at `/var/lib` prevents image
growth from consuming the smaller root filesystem and keeps storage capacity
consistent across nodes.

This separation is capacity and failure-domain management, not a backup. Docker
state on a failed disk is still lost, and bind-mounted application content must
be backed up or replicated separately.

### Named non-root administrator with key-only SSH

An attributable user plus `sudo` provides an audit boundary that direct root
login does not. Public-key-only authentication avoids reusable server-side
password verifiers and reduces automated password attacks. Disabling root SSH,
keyboard-interactive login, forwarding, and excess authentication attempts
reduces exposed SSH functionality.

The `docker` group remains root-equivalent because members can mount or modify
host resources through the daemon. Its membership should be as narrow as sudo
membership and reviewed regularly.

### Event-driven key synchronization

A systemd path unit reacts when Node 1's managed `authorized_keys` changes and a
oneshot service copies the new state to Node 2. This is simple, auditable, and
fast for two machines. The transfer needs a separate automation identity so
replacing the user's login key does not remove the credential required for the
next synchronization.

For more nodes, use configuration management or an SSH certificate authority.
Point-to-point file replication scales poorly, can propagate accidental
deletion, and requires careful atomic replacement and ownership checks.

### Layered host hardening

The controls solve different problems:

- SSH configuration reduces authentication and remote-feature exposure.
- Iptables limits reachable services and admits VRRP only where required.
- Fail2ban temporarily blocks repeated SSH failures that reach the daemon.
- Automatic security updates shorten exposure to known package vulnerabilities.

No single layer replaces the others. Docker also programs iptables rules, so
container restrictions belong in the `DOCKER-USER` chain and must be tested
after daemon restarts.

### Official Docker Engine packages

Using Docker's maintained Engine and Compose plugin keeps the CLI, daemon,
Buildx, and Compose versions compatible. Repository setup must follow the
installed distribution and be revisited during OS upgrades. Package origin and
signing-key fingerprints should be recorded as deployment evidence.

## Rejected alternatives

- **Password SSH:** simpler bootstrap, but a larger brute-force and credential
  reuse risk.
- **One large root disk:** fewer mount steps, but Docker growth can exhaust the
  OS filesystem and complicate capacity management.
- **Copying keys manually:** acceptable once, but it does not meet the automatic
  update requirement and is easy to drift.
- **Kubernetes or another orchestrator:** excessive control-plane and operational
  complexity for one static service on two VMs.

## Risks and controls

| Risk | Control |
|---|---|
| Wrong disk formatted | Verify serial, size, filesystem, and mount state from console before formatting |
| SSH lockout | Validate with `sshd -t` and a second key-only session before closing the first |
| Key sync removes its own access | Use a separate automation identity and test repeated key changes |
| Firewall breaks Docker or VRRP | Allow required traffic first, test from console, persist only verified rules |
| `/var/lib` fills | Monitor filesystem usage and prune only under an explicit retention policy |
