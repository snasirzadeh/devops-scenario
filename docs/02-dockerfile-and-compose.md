# Build a lightweight, Dockerized web server.

The project requires a lightweight Dockerized web server but does not require a
specific web-server product. This implementation uses Nginx with the
`nginx:1.31.4-alpine` base image.

## 1. Dockerfile and containerization

The root `Dockerfile` installs the requested diagnostic tools without caching
the Alpine package index, creates the non-root `nginx` user, changes ownership
of the required Nginx directories, and runs the web server as `nginx` on port
8080.

### Build the image

From the repository root:

```bash
docker compose build
```

`--pull` refreshes the mutable base-image tag for a deliberate rebuild. For a
reproducible release, record and pin the approved base-image digest after the
image has passed vulnerability scanning.

### Packet-capture capability

Installing `tcpdump` and `tcpflow` does not grant packet-capture privileges.
The normal service should remain without extra Linux capabilities. For an
approved, temporary diagnostic container only:

```bash
docker compose run --rm --cap-add NET_RAW --cap-add NET_ADMIN nginx tcpdump -i any
```

## 2. Docker Compose and mounts

`docker-compose.yml` builds the local image, maps host port 80 to container port
8080, creates the isolated network, and bind-mounts the site, Nginx
configuration, and logs from the host.

### Host layout

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

Create the log directory and keep `html/` and `nginx/` readable by the
container:

```bash
mkdir logs
sudo chmod 750 logs
sudo chown 101:101 logs
docker compose build
docker compose run --rm nginx id
```

The non-root Nginx process must be able to write to `logs/`. Apply the ownership
and permissions required by the UID/GID reported by the `id` command.

### Validate and start

```bash
docker compose run --rm nginx nginx -t
docker compose up --wait
docker compose ps
curl http://127.0.0.1/
```

Only host port 80 is published. Nginx listens on port 8080 inside the container.

### Modify content from the host

Edit `html/index.html` on either node. Because it is a bind mount, the running
container sees the saved file immediately and the image does not need to be
rebuilt.

```bash
vim html/index.html
curl --fail http://127.0.0.1/
```

For an Nginx configuration change, validate before reloading:

```bash
docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload
```

### Network verification

Compose attaches the `nginx` service to the project-scoped `isolated` bridge
network. The service is reachable from the host only through the published
`80:8080` mapping.

```bash
docker compose ps
docker compose port nginx 8080
docker inspect "$(docker compose ps -q nginx)" --format '{{json .NetworkSettings.Ports}}'
```

The expected host publication is only `0.0.0.0:80`, and possibly `[::]:80` when
IPv6 is enabled.

### Bind mounts

| Host path | Container path | Mode | Purpose |
|---|---|---|---|
| `./html` | `/usr/share/nginx/html` | Read-only | Website content |
| `./nginx/nginx.conf` | `/etc/nginx/nginx.conf` | Read-only | Nginx configuration |
| `./logs` | `/var/log/nginx` | Read-write | Access and error logs |

### What survives container recreation

| Data | Location | After `docker compose up --force-recreate` |
|---|---|---|
| Web page | Host bind mount `./html` | Remains |
| Nginx configuration | Host bind mount `./nginx/nginx.conf` | Remains |
| Access and error logs | Host bind mount `./logs` | Remain |
| Changes made in the container writable layer | Container filesystem | Lost |
| Image contents | Local Docker image store | Remain until image removal or pruning |
| Container identity, PID, and runtime state | Docker metadata and runtime | Replaced |

Bind mounts remain because their source is outside the container writable layer.
Deleting a container removes its writable layer and runtime metadata but does
not delete the mounted host files. Deleting a host file also removes the
persistent copy presented to the container.
