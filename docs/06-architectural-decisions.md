# Architectural Decisions

## 1. Why I used Debian 13

The project requires Linux but does not mandate a distribution. I selected
Debian 13 (Trixie) because Debian is a widely used Linux distribution, I have
more experience administering it, and it has been stable and trouble-free in
my previous work.

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

During the OS installation, I selected the graphical installer's option to use
the entire system disk with LVM. At that stage, manually planning and creating
all of the logical volumes in the installer was unfamiliar and made the initial
setup more complicated than necessary. Using the guided option gave the system
disk a reliable LVM layout while allowing me to complete the OS installation
with less risk of a partitioning mistake.

After the OS was installed, I configured the second disk from the command line.
I created its physical volume, volume group, and logical volume, then formatted
and mounted it at `/var/lib`. Separating this work from the graphical installer
made each step easier to understand and verify. It also demonstrates that I can
manage LVM directly with its command-line tools rather than relying only on the
installer's guided configuration.

## 3. Nginx Alpine as the web-server implementation

The project requires a lightweight Dockerized web server but does not mandate a
specific product. I selected Nginx because I have used it extensively and have
more experience configuring, securing, monitoring, and troubleshooting it than
other web servers. Using a familiar product reduces configuration mistakes and
makes operational problems faster to diagnose.

Nginx is also well suited to this project because it serves static content
efficiently, has straightforward configuration, supports reverse proxying if
the application grows, and runs with a small resource footprint. The
`nginx:1.31.5-alpine` image combines those capabilities with a compact base
image, which reduces image size and unnecessary packages. Other web servers
could satisfy the requirements, but Nginx provides the best balance of
familiarity, simplicity, performance, and maintainability for this deployment.

## 4. Systemd for automation

Systemd path, service, and timer units manage SSH-key synchronization and daily
monitoring. This uses the operating system's existing service manager and keeps
execution and logs visible through systemd.

## 5. Crontab for the three-day log rotation schedule

The project requires the Nginx logs to be rotated every three days. Logrotate
provides standard frequency options such as daily, weekly, and monthly, but it
does not provide a direct option for an every-three-days schedule. I therefore
use a root crontab entry to run logrotate at midnight every third calendar day.

Cron controls when the command runs, while the policy in
`logrotate/nginx-docker` continues to control retention, compression, and the
signal that tells Nginx to reopen its log files. The command uses logrotate's
force option because cron, rather than logrotate's standard frequency options,
is responsible for enforcing the required schedule.

## 6. Keepalived for failover

Keepalived provides a virtual IP shared by the two nodes. Node 1 is preferred,
and Node 2 takes over when Node 1 shuts down or its local web-service health
check fails.
