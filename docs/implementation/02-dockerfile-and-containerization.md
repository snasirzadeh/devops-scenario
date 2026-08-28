# Dockerfile & Containerization — Implementation

The root `Dockerfile` builds on `nginx:stable-alpine`, installs the requested
diagnostic tools without caching the Alpine package index, changes ownership of
Nginx's cache, and runs the server as the `nginx` user on port 8080.

## Build the image

From the repository root:

```bash
docker build --pull --tag devops-scenario-nginx:local .
docker image ls devops-scenario-nginx:local
docker history devops-scenario-nginx:local
```

`--pull` refreshes the mutable base-image tag for a deliberate rebuild. For a
reproducible release, record and pin the approved base-image digest after the
image has passed vulnerability scanning.

## Verify the runtime identity and tools

```bash
docker run --rm devops-scenario-nginx:local id
docker run --rm devops-scenario-nginx:local sh -c \
  'command -v curl && command -v tcpdump && command -v tcpflow && command -v vim && command -v htop'
```

The first command must report a non-zero UID for `nginx`. The image declares
port 8080 because an unprivileged process should not bind directly to port 80.

Run a standalone smoke test:

```bash
docker run --rm --name nginx-smoke -p 8080:8080 \
  -v "$PWD/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/html:/usr/share/nginx/html:ro" \
  devops-scenario-nginx:local
```

From another terminal:

```bash
curl --fail http://127.0.0.1:8080/
```

## Security and size checks

Scan the built image with the scanner approved by the environment. Fail the
release on unreviewed critical or high-severity findings, and rebuild regularly
to receive Alpine and Nginx security fixes.

Useful checks include:

```bash
docker inspect devops-scenario-nginx:local --format '{{.Config.User}} {{json .Config.ExposedPorts}}'
docker image inspect devops-scenario-nginx:local --format '{{.Size}}'
```

The image intentionally uses `apk add --no-cache`, which avoids persisting a
package-index cache. `.dockerignore` also excludes repository metadata and
runtime logs from the build context.

The diagnostic packages increase the production attack surface and image size.
If this is promoted beyond a troubleshooting lab, maintain two targets: a slim
runtime image and a separately authorized diagnostics image.

## Packet-capture capability

Installing `tcpdump` and `tcpflow` does not grant packet-capture privileges.
The normal service should remain without extra Linux capabilities. For an
approved, temporary diagnostic container only:

```bash
docker compose run --rm --cap-add NET_RAW --cap-add NET_ADMIN nginx tcpdump -i any
```

Remove the temporary container when the investigation ends; do not add these
capabilities permanently to `docker-compose.yml`.

## Acceptance checks

- The image builds without package-manager cache files.
- `docker inspect` reports `nginx` as the configured user and `8080/tcp` exposed.
- All requested troubleshooting tools are present.
- Nginx serves the checked-in HTML with the checked-in configuration.
- The normal container has no added capabilities or privileged mode.
