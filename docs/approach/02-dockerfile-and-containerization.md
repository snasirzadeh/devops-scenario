# Dockerfile & Containerization — Approach

[Documentation index](../README.md) · [Implementation](../implementation/02-dockerfile-and-containerization.md)

## Goal

Package a predictable Nginx runtime that is small, starts without root, contains
the requested troubleshooting tools, and keeps mutable site data outside the
image.

## Design choices

### `nginx:stable-alpine` base

The official Nginx Alpine variant provides the server's expected directory
layout and entrypoint with a smaller base than a general-purpose distribution.
The `stable` line favors predictable Nginx behavior over early adoption of mainline
features.

The tag is mutable, so releases should record an approved digest. Small images
reduce transfer time and the number of installed packages, but size alone is not
a security guarantee; the built artifact still requires scanning and regular
rebuilds.

### Non-root runtime on port 8080

The image changes to the existing `nginx` user after package installation and
cache-directory preparation. Listening on 8080 avoids granting the process the
capability required for a privileged port below 1024. Compose performs the
host-side `80:8080` mapping.

This contains damage from an Nginx compromise, but it is not a sandbox by
itself. The service should also avoid privileged mode, host namespaces, Docker
socket mounts, writable configuration, and unnecessary capabilities.

### Tools installed without a package cache

`apk add --no-cache` installs `bash`, `curl`, `htop`, `tcpdump`, `tcpflow`, and
`vim` without retaining the package index. This meets the exercise's operational
diagnostics requirement and avoids a separate cleanup layer.

Those tools make the image larger and add executable code that production Nginx
does not need. A mature delivery pipeline should use a multi-target strategy:

- a minimal runtime target for ordinary service;
- an explicitly selected diagnostics target for incident response.

An ephemeral diagnostics container can join the same network or namespace when
approved, keeping packet-capture capabilities out of the long-running service.

### Configuration and content excluded from the image

The image contains the server and tools; Compose supplies HTML, Nginx
configuration, and logs as bind mounts. This separates build-time dependencies
from environment-specific state and allows the host page to change immediately.
The trade-off is that the image alone is not a complete deployable artifact—the
repository files and their permissions are also required.

### Explicit foreground process

`nginx -g 'daemon off;'` keeps the main server process in the foreground so
Docker can supervise it and propagate stop signals. A background daemon would
make container lifecycle and exit status unreliable.

## Image optimization strategy

1. Keep `.dockerignore` narrow enough to exclude Git data, documentation,
   runtime logs, and unrelated files from the build context.
2. Install packages in one non-caching operation and remove build-only
   dependencies in the same layer if any are introduced.
3. Do not copy mutable site or log data into the image.
4. Pin the approved base digest for releases and rebuild when fixes are issued.
5. Compare `docker history`, compressed image size, and scanner results in CI.
6. Prefer a separate diagnostics target when production size and attack surface
   matter more than in-container convenience.

## Alternatives considered

| Alternative | Benefit | Reason not selected here |
|---|---|---|
| Debian-based Nginx image | Familiar tools and libc behavior | Larger base for this simple static server |
| Scratch/distroless image | Very small runtime | Harder Nginx packaging and conflicts with requested tools |
| Root process binding port 80 | Simpler port mapping | Unnecessary privilege |
| Install tools at incident time | Smaller steady-state image | Requires package network access and changes the running container |
| Bake HTML into the image | Immutable, portable release | Does not meet host-editable HTML requirement |

## Security boundaries

`EXPOSE 8080` is image metadata, not a firewall rule. Network reachability comes
from Compose publication and host firewall policy. Likewise, including
`tcpdump` does not automatically grant `NET_RAW` or `NET_ADMIN`; that separation
is intentional and should remain explicit.
