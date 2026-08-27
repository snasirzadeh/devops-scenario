# Docker Compose & Mounts — Approach

[Documentation index](../README.md) · [Implementation](../implementation/03-docker-compose-and-mounts.md)

## Goal

Keep the service definition small and repeatable while allowing operators to
edit the page and inspect configuration and logs directly on the host. Expose
only HTTP port 80 to clients.

## Data and traffic flow

```text
client :80
    |
host port 80
    |
Compose bridge -> container :8080 -> Nginx
                                  |-- reads ./html
                                  |-- reads ./nginx/nginx.conf
                                  `-- writes ./logs
```

Compose creates a project-scoped bridge network. The container receives a
private address on that bridge, and Docker publishes only the declared
`80:8080` mapping on the host.

## Why bind mounts

The checklist explicitly requires host-editable HTML, configuration, and logs.
Bind mounts make the host files the source of truth and expose changes without
an image rebuild. They also integrate cleanly with host logrotate and simple
file-based backup tools.

The trade-offs are important:

- deployments depend on exact host paths and permissions;
- a host edit immediately affects the running service;
- the container can alter writable host data;
- SELinux-enabled hosts may require an appropriate mount label;
- the image is not self-contained.

Configuration and HTML should be mounted read-only when live write access from
the container is unnecessary. Logs must remain writable by the numeric Nginx
UID/GID.

## Persistence model

Docker combines immutable image layers with one writable layer unique to each
container. Removing the container removes that writable layer. A bind mount
replaces a path in the container with a view of a host path, so writes go to the
host filesystem and exist independently of the container ID.

This explains both sides of the requirement:

- a file created in an unmounted container directory disappears on recreation;
- `html/`, `nginx/nginx.conf`, and `logs/` remain because they are host files;
- image contents remain available until the image itself is removed;
- in-memory state, processes, and open connections always disappear.

Persistence is not durability. A host disk failure or accidental host-side
deletion still destroys bind-mounted data. Backups and cross-node content
synchronization are separate responsibilities.

## Why host port 80 maps to container port 8080

Clients use conventional HTTP port 80, while Nginx remains unprivileged inside
the container. Docker performs destination NAT from the host port to the
container port. No SSH, diagnostics, admin, or alternate web port is published.

The default binding may listen on all host addresses, including the physical
addresses and VIP. If policy calls for VIP-only serving, use an explicit host IP
after confirming how that interacts with failover and non-local address binding.

## Configuration lifecycle

An HTML edit requires no reload because Nginx reads the requested file on each
request. A configuration edit does require `nginx -t` followed by a graceful
reload. Recreating the container is also valid but causes a larger interruption
and should not replace syntax validation.

## Alternatives considered

| Alternative | Benefit | Reason not selected |
|---|---|---|
| Named Docker volumes | Docker-managed lifecycle and portability | Less direct host editing; does not meet the stated mount requirement as clearly |
| Copy content into image | Immutable artifact and easy rollback | Host changes require rebuild and redeploy |
| Host network mode | No NAT or bridge | Exposes more host network surface and weakens isolation |
| Multiple published ports | Easier direct diagnostics | Violates the only-port-80 requirement |

## Operational implications

The same directory layout must exist on both nodes. Compose project naming also
affects generated container and network names, so external automation should
target the service through `docker compose`, not assume a fixed container name.
