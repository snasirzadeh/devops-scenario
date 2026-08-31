# Build a lightweight, Dockerized web server.

The goal is to build a small and maintainable Docker image that runs Nginx as a
non-root user, keeps website content, configuration, and logs on the host, and
exposes only the required HTTP port through an isolated container network.

## 1. Dockerfile and containerization

The project requires a lightweight Dockerized web server but does not require a
specific web-server product. This implementation uses Nginx with the
`nginx:1.31.4-alpine` base image.

The root `Dockerfile` installs the requested diagnostic tools without caching
the Alpine package index, creates the non-root `nginx` user, changes ownership
of the required Nginx directories, and runs the web server as `nginx` on port
8080.

### Build the image

From the repository root:

```bash
docker compose run --rm nginx id
mkdir -p logs
sudo chown 101:101 logs
sudo chmod 750 logs
docker compose build
```

In this image, the Nginx user uses UID and GID `101:101`. Verify those values
with the `id` command, then create the host log directory before starting the
application service. This ownership allows Nginx to write to the bind-mounted
directory, while mode `750` limits access to its owner and group.

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

### Validate and start

```bash
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

### Network verification

Compose attaches the `nginx` service to the project-scoped `isolated` bridge
network. The service is reachable from the host only through the published
`80:8080` mapping.

```bash
docker compose ps
docker compose port nginx 8080
```

The expected host publication is only `0.0.0.0:80`.

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
