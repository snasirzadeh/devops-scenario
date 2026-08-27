# Log Management & Monitoring — Approach

[Documentation index](../README.md) · [Implementation](../implementation/04-log-management-and-monitoring.md)

## Goal

Bound log growth, preserve recent history, produce a daily human-readable signal,
and deliver it without depending on an external monitoring or mail service.

## Logging design

Nginx writes `access.log` and `error.log` into a host bind mount. Host logrotate
can therefore manage the files even if the container is replaced. Rotation and
monitoring are intentionally outside the application container because they are
host operations with their own schedules and permissions.

### Rotate every three days

Three-day rotation limits individual file growth while retaining useful local
history. Compression reduces disk usage; delayed compression keeps the newest
archive easy for tools to inspect. `missingok` and `notifempty` make the policy
tolerant of a newly deployed or idle server.

Rotation renames the active file. Nginx retains an open file descriptor, so it
must receive a reopen signal after rotation. The action must target the actual
Compose service/container and must be tested—silently ignoring a wrong name can
make rotation appear successful while Nginx continues writing to the archive.

Copy-truncate is an alternative, but it can lose or duplicate lines during the
copy/truncate window. A graceful reopen is preferred when the daemon supports it.

### Daily systemd timer

A systemd timer provides dependency-aware execution, centralized journal output,
an inspectable next-run time, and `Persistent=true` catch-up after downtime. A
cron job is shorter, but its environment, error reporting, and missed-run
behavior are less explicit.

The oneshot service runs as the non-root operator because parsing application
logs and sending local mail should not require root. Log file group membership
and permissions should be set accordingly.

## Report semantics

### Top three requesting IP addresses

In the default Nginx combined log format, field one is the client address.
Counting, sorting descending, and taking three entries answers the checklist.
If Nginx later sits behind another proxy, field one may be the proxy address;
trusted real-IP configuration is then required before the report is meaningful.

Ties at the third rank are not all retained by a simple `head -3`. That behavior
is acceptable only if the requirement means exactly three rows rather than all
addresses tied for third.

### HTTP 404 detection

The access log is authoritative for HTTP response status and should be parsed by
field using the configured log format. Searching for the digits `404` anywhere
can falsely match a URL, byte count, timestamp fragment, or client data. The
error log is supplemental: some missing-resource messages appear there, but not
every access-log 404 is guaranteed to have a matching error entry.

### Local mail

Local delivery lets the operator read reports with `mail` after login and avoids
external credentials or network dependencies. It is appropriate for this lab,
but it does not alert anyone who is not logging into the host. A production
system should forward alerts to a monitored channel and define severity,
deduplication, ownership, and response time.

## Failure handling

The script uses strict Bash error handling so unexpected pipeline or command
failures surface to systemd. Expected conditions—missing logs on first run or no
404 responses—should be represented in the report instead of failing the unit.
A temporary report under `/tmp` must use safe permissions and cleanup behavior;
for concurrent or security-sensitive use, create it with `mktemp` and a trap.

## Alternatives considered

| Alternative | Benefit | Reason not selected here |
|---|---|---|
| Docker JSON logs | Native engine collection | Nginx files are already required and host-mounted |
| Cron | Universal and simple | Weaker missed-run behavior and observability than systemd timers |
| Remote log platform | Search, dashboards, centralized retention | Extra infrastructure and credentials beyond this project |
| External SMTP | Reports reach remote inboxes | The requirement specifically asks for local `mail` access |
| `copytruncate` | No daemon signal needed | Race can lose log records |

## Retention and privacy

Access logs contain IP addresses and may contain sensitive URLs or identifiers.
Ten rotated files at a three-day interval represents roughly one month of local
history, but the actual policy must follow legal, security, and capacity
requirements. Limit permissions, avoid committing logs, and document deletion
and backup behavior.
