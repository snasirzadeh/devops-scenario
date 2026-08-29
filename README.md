# Project Requirements Checklist

## 1. OS Initial, User, SSH & Docker Setup

* **Dual VM Setup:** Install 2 Debian 13 (Trixie) VMs with 2 virtual disks each:
  * **Disk 1 (10GB):** Mounted on `/`
  * **Disk 2 (10GB):** Mounted on `/var/lib/`
* **User & SSH Configuration:**
  * Create the non-root `debian` user with `sudo` privileges.
  * Restrict login exclusively to the provided `ssh-rsa` key.
  * Configure automatic key replication so changing the key on Node 1 updates Node 2 automatically.
* **Docker Installation:** Install Docker Engine on both servers.

---

## 2. System Hardening

* **SSH Hardening:** Use a non-default port, disable root and password login, and allow public-key authentication.
* **Fail2ban:** Monitor SSH and ban repeated failed login attempts.
* **Firewall:** Install `iptables` and persist the host firewall configuration.

---

## 3. Dockerfile, Docker Compose & Mounts

* **Purpose:** Build a lightweight, Dockerized web server.
* **Base Image:** Use a lightweight base image and run the web server as a non-root user.
* **Troubleshooting Tools:** Pre-install `curl`, `tcpdump`, `tcpflow`, `vim`, `htop`, etc.
* **Optimization:** Keep the image minimal and secure.
* **HTML Host Mount:** Design a simple `index.html` page stored on the Host that can be modified directly from the host filesystem.
* **Config & Log Mounts:** Mount web server configuration files and log directories from the Host.
* **Network Isolation:** Isolate the container network, opening **only** port 80.
* **Persistence Concept:** Explain what data is lost vs. what data remains if a container is deleted and recreated, including the technical reasoning.

---

## 4. Log Management & Monitoring

* **Logrotate:** Write a `logrotate` policy to rotate web server logs every 3 days.
* **Monitoring Script:** Create a monitoring script that runs daily to:
  1. Parse `access.log` and log the top 3 requesting IP addresses.
  2. Check `error.log` / `access.log` for HTTP 404 errors.
  3. Email the results locally to the non-root user (accessible via the `mail` command upon login).

---

## 5. High Availability & Failover

* **Virtual IP / Redundancy:** Route web requests to Server 1 by default using a single public IP.
* **Automatic Failover:** Automatically reroute traffic to Server 2 if Server 1 encounters either of these two conditions:
  1. Server 1 powers down / shuts off.
  2. The Docker service on Server 1 stops.

---

## 6. Documentation & Rationale

* **Repository & Readme:** Provide all scripts (Bash, config files, `.md` docs) in a Git repository with a `README.md` detailed enough for someone to recreate the environment from scratch.
* **5 Key Architectural Decisions:** Document at least 5 design decisions made during the project and justify the reasoning behind each choice (e.g., choice of OS, web server, scheduling tool, etc.).
