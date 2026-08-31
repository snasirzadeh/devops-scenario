# Architectural Decisions

## 1. Why I used Debian 13

The project requires Linux but does not mandate a distribution. I selected
[Debian 13 (Trixie)](https://www.debian.org/releases/trixie/) because Debian is
a widely used Linux distribution, I have more experience administering it, and
it has been stable and trouble-free in my previous work.

Most of my Linux experience is with Debian-based distributions rather than
Red Hat-based distributions. I am more familiar with Debian's package
management, filesystem conventions, configuration, and troubleshooting
workflow. Choosing the ecosystem I know best reduces setup time, avoids
unnecessary operational risk, and makes the system easier for me to maintain.

My main priorities were maximum stability and a minimal base system. I prefer
Debian over Ubuntu for this type of deployment because Debian's stable releases
focus on being ready and thoroughly tested, while Ubuntu follows a time-based
release schedule, commonly publishing releases in April and October with
defined support periods. In my experience, Debian's approach produces a more
predictable long-lived server platform with fewer unnecessary changes. This is
a personal operational preference rather than a claim that Ubuntu cannot meet
the project's requirements.

## 2. LVM and a separate `/var/lib`

The OS and data disks use LVM. Docker stores its runtime data under
`/var/lib/docker`, so mounting the second disk at `/var/lib` prevents Docker data
from consuming the root filesystem.

## 3. Nginx Alpine as the web-server implementation

The project requires a lightweight Dockerized web server but does not mandate a
specific product. I selected Nginx because I have used it extensively and have
more experience configuring, securing, monitoring, and troubleshooting it than
other web servers. Using a familiar product reduces configuration mistakes and
makes operational problems faster to diagnose.

Nginx is also well suited to this project because it serves static content
efficiently, has straightforward configuration, supports reverse proxying if
the application grows, and runs with a small resource footprint. The
`nginx:1.31.4-alpine` image combines those capabilities with a compact base
image, which reduces image size and unnecessary packages. Other web servers
could satisfy the requirements, but Nginx provides the best balance of
familiarity, simplicity, performance, and maintainability for this deployment.

## 4. Systemd for automation

Systemd path, service, and timer units manage SSH-key synchronization and daily
monitoring. This uses the operating system's existing service manager and keeps
execution and logs visible through systemd.

## 5. Keepalived for failover

Keepalived provides a virtual IP shared by the two nodes. Node 1 is preferred,
and Node 2 takes over when Node 1 shuts down or its local web-service health
check fails.
