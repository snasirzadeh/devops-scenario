# Log Management & Monitoring — Implementation

This section deploys the policy in `logrotate/nginx-docker` and the daily
monitoring job under `monitoring/`. Complete the path and identity normalization
in the docs index before copying any unit or policy into the host OS.

## 1. Prepare local mail delivery

Install a local mail transport and the `mail` client supported by the chosen OS.
For a Debian host using local-only Postfix delivery:

```bash
sudo apt-get update
sudo apt-get install -y mailutils postfix
```

Choose **Local only** during package configuration. Verify delivery to the
non-root operator:

```bash
printf '%s\n' 'monitoring mail test' | mail -s 'mail test' debian
sudo -iu debian mail
```

No external SMTP relay is required for the checklist; the report is stored in
the local user's mailbox.

## 2. Normalize the checked-in monitoring files

Review these values before installation:

| File | Values that must agree |
|---|---|
| `monitoring/monitor.sh` | `LOG_DIR`, `MAIL_TO` |
| `monitoring/nginx-monitor.service` | `User`, `Group`, `ExecStart` |
| `monitoring/nginx-monitor.timer` | no host-specific value |

The checked-in service currently names `nginx-monitor.sh` while the repository
script is named `monitor.sh`; make `ExecStart` point to the real installed path.
The script should inspect HTTP status codes in `access.log` as the authoritative
source of 404 responses and may additionally search `error.log` for related
messages. Validate this requirement before accepting the deployment.

Install the normalized files:

```bash
sudo install -m 0750 -o debian -g debian monitoring/monitor.sh /usr/local/bin/nginx-monitor.sh
sudo install -m 0644 monitoring/nginx-monitor.service /etc/systemd/system/
sudo install -m 0644 monitoring/nginx-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nginx-monitor.timer
```

Run the service without waiting for the timer:

```bash
sudo systemctl start nginx-monitor.service
sudo systemctl status nginx-monitor.service --no-pager
sudo journalctl -u nginx-monitor.service -n 100 --no-pager
sudo -iu debian mail
```

Confirm that the report contains the three highest request counts and all 404
findings for the intended reporting period. `Persistent=true` causes systemd to
run a missed daily job after the host comes back online.

## 3. Install and validate log rotation

Before installation, normalize the absolute log path and the command used to
reopen Nginx's file descriptors. Compose does not guarantee a container named
`nginx`; its service is named `nginx`, while the generated container name is
usually project-prefixed. Prefer a Compose-aware post-rotate command using the
absolute Compose file path, or deliberately define and document a fixed
container name.

Validate the exact logrotate syntax supported by the target OS. The installed
policy must rotate no more often than every three days, retain the agreed number
of archives, compress old files, and signal Nginx after rotation. Then install:

```bash
sudo install -m 0644 logrotate/nginx-docker /etc/logrotate.d/nginx-docker
sudo logrotate --debug /etc/logrotate.d/nginx-docker
```

After the debug pass is clean, force one controlled test and verify that Nginx
continues writing to the new active log:

```bash
sudo logrotate --force --verbose /etc/logrotate.d/nginx-docker
curl --fail http://127.0.0.1/not-found-for-rotation-test || true
ls -lah logs/
tail -n 5 logs/access.log
```

The reopen signal matters because renaming a file does not change an already
open file descriptor. Without it, Nginx can continue writing into the renamed
archive instead of the newly created active log.

## 4. Validate timer scheduling

```bash
systemctl list-timers nginx-monitor.timer --all
systemctl cat nginx-monitor.service nginx-monitor.timer
```

Record the next run time and test local mail retrieval as the non-root user.

## Acceptance checks

- The logrotate configuration passes a debug parse with no errors.
- A forced rotation creates an archive and Nginx writes new requests to the new
  `access.log`.
- The daily timer is enabled and has a next trigger time.
- The report ranks the top three source IPs by request count.
- The report finds 404 responses from `access.log` and related entries from
  `error.log` when present.
- The non-root user can read the delivered report using `mail`.
