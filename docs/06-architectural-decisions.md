# Architectural Decisions

## 1. Debian 13 as the Linux implementation

The project requires Linux but does not mandate a distribution. Debian 13
(Trixie) was selected because it provides a minimal installation, stable package
management, systemd, LVM, and the packages required by the project.

## 2. Two virtual machines

Two independent VMs are used so the web service can fail over when the primary
VM shuts down or its Docker service fails. Running two containers on one VM
would not protect the service from a VM or OS failure.

## 3. LVM and a separate `/var/lib`

The OS and data disks use LVM. Docker stores its runtime data under
`/var/lib/docker`, so mounting the second disk at `/var/lib` prevents Docker data
from consuming the root filesystem.

## 4. Nginx Alpine as the web-server implementation

The project requires a lightweight Dockerized web server but does not require
Nginx. This implementation selects `nginx:1.31.4-alpine` because it combines a
small Alpine base with a production web server.

## 5. Non-root container user

The image creates the `debian` user and runs Nginx as that user on port 8080.
Host port 80 is mapped to container port 8080 because a non-root process does
not bind directly to a privileged port.

## 6. Host bind mounts

The HTML, Nginx configuration, and logs are bind-mounted from the host. Website
content and configuration can therefore be changed without rebuilding the
image, and these files remain when a container is recreated.

## 7. Systemd for automation

Systemd path, service, and timer units manage SSH-key synchronization and daily
monitoring. This uses the operating system's existing service manager and keeps
execution and logs visible through systemd.

## 8. Keepalived for failover

Keepalived provides a virtual IP shared by the two nodes. Node 1 is preferred,
and Node 2 takes over when Node 1 shuts down or its local web-service health
check fails.

## 9. Layered host hardening

SSH restrictions, Fail2ban, and iptables provide separate protection layers.
SSH limits remote access, Fail2ban responds to repeated authentication failures,
and iptables controls traffic reaching each host.
