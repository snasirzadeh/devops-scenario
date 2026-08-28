# Docker Compose & Mounts — Implementation

`docker-compose.yml` builds the local image, maps host port 80 to container port
8080, and bind-mounts the site, Nginx configuration, and logs from the host.

## Host layout

```text
devops-scenario/
├── Dockerfile
├── docker-compose.yml
├── html/index.html
├── nginx/nginx.conf
└── logs/
    ├── access.log
    └── error.log
```

Keep `html/` and `nginx/` readable by the container. The non-root Nginx process
must also be able to write to `logs/`. Determine its numeric identity before
setting host ownership:

```bash
docker compose build
docker compose run --rm nginx id
```

Apply only the ownership and permissions required by the UID/GID shown in that
output. Avoid world-writable log directories.

## Validate and start

```bash
docker compose config --quiet
docker compose run --rm nginx nginx -t
docker compose up -d --build
docker compose ps
curl --fail http://127.0.0.1/
```

On systems with a host firewall, ensure port 80 is allowed. Do not publish
Nginx's 8080 directly or publish any troubleshooting port.

## Modify content from the host

Edit `html/index.html` on either node. Because it is a bind mount, the running
container sees the saved file immediately; rebuilding the image is unnecessary.

```bash
curl --fail http://127.0.0.1/
```

For an Nginx configuration change, validate before reloading:

```bash
docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload
```

## Network verification

Compose creates a project-scoped bridge network by default. The `nginx` service
is reachable from the host only through the single published mapping `80:8080`.

```bash
docker compose ps
docker compose port nginx 8080
docker inspect "$(docker compose ps -q nginx)" --format '{{json .NetworkSettings.Ports}}'
```

The expected host publication is only `0.0.0.0:80` (and possibly `[::]:80` if
IPv6 is enabled). If access should be limited to a specific host address, bind
that address explicitly in the Compose `ports` entry.

## What survives container recreation

| Data | Location | After `docker compose up --force-recreate` |
|---|---|---|
| Web page | Host bind mount `./html` | Remains |
| Nginx configuration | Host bind mount `./nginx/nginx.conf` | Remains |
| Access and error logs | Host bind mount `./logs` | Remain |
| Changes made in the container writable layer | Container filesystem | Lost |
| Image contents | Local Docker image store | Remain until image removal/pruning |
| Container identity, PID, and runtime state | Docker metadata/runtime | Replaced |

Bind mounts remain because their source is outside the container writable layer.
Deleting a container removes only its writable layer and runtime metadata; it
does not delete the mounted host files. Deleting the host files, however, deletes
the persistent copy.

Demonstrate this safely:

```bash
docker compose up -d
curl --fail http://127.0.0.1/
docker compose up -d --force-recreate
curl --fail http://127.0.0.1/
test -f html/index.html && test -f logs/access.log
```

Do not use `docker compose down --volumes` casually in projects that later add
named volumes.

## Stop and inspect

```bash
docker compose logs --tail=100 nginx
docker compose down
```

## Acceptance checks

- Host port 80 serves `html/index.html`.
- A host-side HTML edit appears without a rebuild.
- Nginx loads the bind-mounted configuration.
- Access and error logs are written beneath `logs/`.
- Only HTTP port 80 is published.
- HTML, configuration, and logs survive container deletion and recreation.
