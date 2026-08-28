# Documentation & Rationale — Approach

## Documentation model

The root README remains the requirements checklist and entry point. Each numbered
section links to two focused pages: an implementation runbook for doing and
verifying the work, and an approach page for understanding why the design exists.
This avoids mixing commands, operational warnings, and architectural reasoning
into one long checklist.

The repository is the source of truth for non-secret scripts and configuration.
Host inventory and secrets remain external inputs. A deployment is reproducible
only when versioned files, documented substitutions, and validation evidence are
all available.

## Architectural decision record

The project makes the following decisions. Each has a consequence that operators
must accept and test.

| # | Decision | Rationale | Consequence |
|---|---|---|---|
| 1 | Use two independent Linux VMs | Survives one node's OS or power failure | Requires configuration and content consistency across nodes |
| 2 | Use Debian stable as the reference OS | Predictable packages, systemd, and a small server baseline | Commands and package names must be reviewed for another distribution |
| 3 | Mount a 20 GB disk at `/var/lib` | Isolates Docker growth from the smaller root filesystem | Mount must be healthy before Docker starts; it is not a backup |
| 4 | Allow SSH only for a named sudo user with a key | Reduces password/root exposure and improves accountability | Key recovery and emergency console access must be planned |
| 5 | Use systemd path/service units for two-node key sync | Event-driven, observable, and simple at this scale | Needs a separate automation credential; use configuration management at larger scale |
| 6 | Build from the official Alpine Nginx image | Small, familiar server base with maintained defaults | Alpine compatibility and all added packages still require scanning |
| 7 | Run Nginx as non-root on container port 8080 | Avoids privileged bind capability in the container | Docker must map host port 80 to 8080 |
| 8 | Use host bind mounts for HTML, config, and logs | Meets direct host-editing and host log-management requirements | Host paths and numeric permissions become deployment dependencies |
| 9 | Use systemd timers and local mail for daily reports | Observable scheduling with no external mail dependency | Reports are seen only when the operator logs in |
| 10 | Use host logrotate and signal Nginx to reopen files | Bounds disk use without copy-truncate races | Rotation must address the actual running Compose service |
| 11 | Use Keepalived/VRRP active-passive failover | Fast IP movement on a shared Layer 2 network | Does not work unchanged on every cloud and can split-brain if VRRP is blocked |
| 12 | Health-check HTTP through host port 80 | Detects Docker, container, Nginx, and serving failures together | A transient or overly deep HTTP failure can trigger movement |

## Documentation standards

Each implementation page contains:

- scope and prerequisites;
- installation or operating steps;
- explicit environment-specific substitutions;
- safety warnings where a command can cause lockout or data loss;
- acceptance checks with observable outcomes.

Each approach page contains:

- the goal and relevant system boundary;
- selected design and why it fits;
- trade-offs and rejected alternatives;
- operational and security risks.

Commands are examples, not hidden automation. Values such as users, paths,
interfaces, addresses, keys, and secrets must be resolved from inventory before
use. Documentation should be updated in the same change as any behavior or file
layout change.

## Reproducibility boundary

The repository can reproduce application and host configuration, but it cannot
safely contain everything. The following remain outside Git:

- private SSH keys and real Keepalived or mail secrets;
- VM/hypervisor credentials and console access;
- public IP, subnet, gateway, and DNS ownership records;
- backups, raw logs, mail spools, and other runtime data;
- evidence containing client or infrastructure-sensitive data.

These inputs belong in an approved secret manager, asset inventory, or deployment
system. Documentation records their required shape and location without exposing
their values.

## Change and review policy

For every functional change:

1. Update the implementation page and any affected decision or trade-off.
2. Validate shell scripts, Nginx, Compose, systemd, logrotate, SSH, and Keepalived
   with their native tools where applicable.
3. Exercise the smallest safe smoke test, then the relevant failure test.
4. Review the diff for secrets, machine-specific paths, generated logs, and
   private data.
5. Record any deliberate deviation and its owner.

The README should remain a concise checklist. Only its documentation links need
to change when pages move or new checklist sections are added.

## Success criteria

Documentation is successful when a second operator can explain the decisions,
identify required site inputs, reproduce both nodes, verify both failover modes,
and diagnose a failed acceptance check without relying on undocumented knowledge.
