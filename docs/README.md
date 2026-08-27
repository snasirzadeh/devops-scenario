# Project documentation

The documentation follows the six sections in the root `README.md`. Each section
has two views:

- **Implementation** is the build, installation, validation, and operations
  runbook.
- **Approach** explains the design, alternatives, trade-offs, and security
  rationale.

| # | Requirement | Implementation | Approach |
|---|---|---|---|
| 1 | Infrastructure & OS Setup | [Implementation](implementation/01-infrastructure-and-os-setup.md) | [Approach](approach/01-infrastructure-and-os-setup.md) |
| 2 | Dockerfile & Containerization | [Implementation](implementation/02-dockerfile-and-containerization.md) | [Approach](approach/02-dockerfile-and-containerization.md) |
| 3 | Docker Compose & Mounts | [Implementation](implementation/03-docker-compose-and-mounts.md) | [Approach](approach/03-docker-compose-and-mounts.md) |
| 4 | Log Management & Monitoring | [Implementation](implementation/04-log-management-and-monitoring.md) | [Approach](approach/04-log-management-and-monitoring.md) |
| 5 | High Availability & Failover | [Implementation](implementation/05-high-availability-and-failover.md) | [Approach](approach/05-high-availability-and-failover.md) |
| 6 | Documentation & Rationale | [Implementation](implementation/06-documentation-and-rationale.md) | [Approach](approach/06-documentation-and-rationale.md) |

## Values to choose before deployment

The checked-in files are examples and contain environment-specific values. Pick
one value for each item below and use it consistently on both nodes.

| Value | Example | Used by |
|---|---|---|
| Application user | `debian` | SSH, systemd, mail, repository ownership |
| Repository path | `/home/debian/devops-scenario` | monitoring, logrotate, Compose |
| Node 1 address | `192.168.1.11` | SSH alias and operations |
| Node 2 address | `192.168.1.12` | SSH alias and operations |
| Virtual IP (VIP) | `192.168.1.10/24` | Keepalived and client access |
| Network interface | `ens18` | Keepalived and firewall rules |
| Compose service | `nginx` | health checks and log reopening |

In particular, review every occurrence of `/home/user`, `/home/debian`,
`/home/sepehr`, `User=`, `Group=`, `MAIL_TO`, `interface`, and the example IP
addresses before installing files into `/etc` or `/usr/local/bin`.

## Recommended reading order

For a new environment, read each approach page before following its paired
implementation page. Complete sections 1 through 5 in order, then use section 6
as the final audit and handover checklist.
