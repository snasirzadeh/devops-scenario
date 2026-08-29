# Dockerfile & Containerization — Web Server Base Image

This section manages the base image used by the project's Nginx web server. The
root `Dockerfile` builds on `nginx:1.31.4-alpine`, installs the requested
diagnostic tools without caching the Alpine package index, creates the non-root
`debian` user, changes ownership of the required Nginx directories, and runs the
web server as `debian` on port 8080.

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

## Packet-capture capability

Installing `tcpdump` and `tcpflow` does not grant packet-capture privileges.
The normal service should remain without extra Linux capabilities. For an
approved, temporary diagnostic container only:

```bash
docker compose run --rm --cap-add NET_RAW --cap-add NET_ADMIN nginx tcpdump -i any
```

Remove the temporary container when the investigation ends; do not add these
capabilities permanently to `docker-compose.yml`.
