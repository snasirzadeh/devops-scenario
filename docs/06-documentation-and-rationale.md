# Documentation & Rationale — Implementation

This page is the final repository, reproduction, and handover checklist. The
paired approach page records the key architectural decisions.

## Repository contents

```text
.
├── README.md                 # Requirements checklist and docs links
├── Dockerfile                # Non-root Nginx image
├── docker-compose.yml        # Service, port, and bind mounts
├── html/                     # Host-managed site content
├── nginx/                    # Nginx configuration
├── logs/                     # Runtime logs; not committed
├── logrotate/                # Host logrotate policy
├── monitoring/               # Daily report script and systemd units
├── keepalived/               # Health check and per-node VRRP configs
├── ssh-key-sync/             # Key sync script and systemd units
└── docs/
    ├── implementation/       # Installation and validation runbooks
    └── approach/             # Design rationale and trade-offs
```

## Recreate the environment

1. Clone the repository on both freshly installed nodes.
2. Follow section 1 to mount disks, create the operator, harden SSH and the host,
   configure key synchronization, and install Docker.
3. Follow section 2 to build and inspect the container image.
4. Follow section 3 to prepare bind-mount permissions and start Nginx.
5. Follow section 4 to install logrotate, local mail, and the monitoring timer.
6. Follow section 5 to install Keepalived and test both failover cases.
7. Run every acceptance checklist and record the results for handover.

## Pre-deployment substitution audit

The examples intentionally require site-specific values. Find every candidate:

```bash
rg -n '/home/(user|debian|sepehr)|User=|Group=|MAIL_TO|192\.168\.1\.|ens18|password' . \
  -g '!logs/**' -g '!.git/**'
```

Resolve all mismatched users and absolute paths. Replace the Keepalived example
secret. Confirm that service filenames match their `ExecStart` targets and that
the logrotate reopen command addresses the actual Compose container.

## Validation commands

Run commands from the repository root unless noted otherwise:

```bash
docker compose config --quiet
docker compose build
docker compose run --rm nginx nginx -t
docker compose up -d
curl --fail http://127.0.0.1/
```

On each host also validate installed system configuration:

```bash
sudo sshd -t
sudo systemctl --no-pager --full status docker
sudo systemctl --no-pager --full status keepalived
systemctl list-timers nginx-monitor.timer --all
sudo logrotate --debug /etc/logrotate.d/nginx-docker
```

Test the SSH key replication, daily report, three-day rotation, container
recreation, host-shutdown failover, and Docker-service failover as described in
the individual runbooks.

## Evidence to retain

- OS version, disk layout, interface names, node addresses, and VIP allocation.
- Redacted SSH daemon, firewall, Fail2ban, and unattended-upgrade configuration.
- Image digest, build date, scan result, and Compose resolved configuration.
- Successful systemd unit/timer status and sample local monitoring mail.
- Logrotate debug output and proof that Nginx writes after rotation.
- Timestamps and observed convergence time for both failover tests.
- Any deviations from the approach pages, with owner and reason.

Never commit private SSH keys, real passwords, mail spools, logs containing client
data, or unredacted secrets.

## Definition of done

- All scripts and non-secret configuration required for recreation are tracked.
- Every README section links to both an implementation and an approach page.
- Host-specific placeholders are documented and resolved in the deployed copy.
- The paired approach page contains at least five justified architectural
  decisions.
- A second operator can recreate and validate the environment using only the
  repository, site inventory, and approved secrets.
