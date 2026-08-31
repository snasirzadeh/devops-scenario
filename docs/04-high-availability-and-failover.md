# High Availability & Failover

The repository uses Keepalived and VRRP to move `192.168.1.10/24` between two
hosts. Node 1 normally owns the VIP. Its health script makes an HTTP request to
the locally published Nginx port, so both a stopped Docker service and an
unhealthy web endpoint reduce Node 1's effective priority below Node 2's.

## 1. Prerequisites

- Both hosts are on the same Layer 2 network and can exchange VRRP protocol 112.
- `ens18` is replaced with the real interface on each host.
- `192.168.1.10` is reserved and unused by DHCP or another host.
- The application is deployed and independently healthy on both nodes.
- Site content and configuration are kept consistent between nodes.
- Host and upstream firewalls allow client HTTP traffic to the VIP.

If the public address is provided by a cloud platform or the nodes do not share
Layer 2, use that platform's floating-IP or load-balancer API instead of VRRP.

## 2. Install Keepalived

Run on both nodes:

```bash
sudo apt install -y keepalived
sudo chmod +x keepalived/http-check.sh
sudo cp keepalived/http-check.sh /usr/local/bin/http-check.sh
```

The `http-check.sh` script requests the local web page and succeeds only when
the HTTP endpoint responds successfully. I prefer this end-to-end check over
checking only whether the Docker service is running because it also detects a
stopped or unhealthy container, an Nginx failure, and an unavailable web
endpoint. A running Docker daemon alone does not prove that users can reach the
web page.

Copy the node-specific configuration:

```bash
# Node 1 only
sudo cp keepalived/keepalived.conf.server1 /etc/keepalived/keepalived.conf

# Node 2 only
sudo cp keepalived/keepalived.conf.server2 /etc/keepalived/keepalived.conf
```

Before starting, replace the example interface, VIP/prefix, authentication
secret, and any environment-specific router ID. Use the same
`virtual_router_id` and authentication values on both nodes, but keep Node 1 at
priority 150 and Node 2 at priority 100. With `weight -60`, a failed Node 1 check
reduces its effective priority to 90, below Node 2.

Validate and start:

```bash
sudo keepalived --config-test --use-file=/etc/keepalived/keepalived.conf
sudo systemctl enable --now keepalived
sudo systemctl status keepalived
```

If the installed Keepalived version uses a different config-test flag, consult
its local `keepalived --help` output before starting the service.

## 3. Confirm steady state

On Node 1:

```bash
ip address show dev ens18
curl --fail http://192.168.1.10/
```

The VIP should be present only on Node 1. On Node 2, inspect logs and confirm it
is in BACKUP state:

```bash
sudo journalctl -u keepalived -n 100
ip address show dev ens18
```

## 4. Test failure mode 1: Node 1 powers off

Keep an independent console on Node 2 and a client continuously requesting the
VIP. Shut down Node 1 during an approved test window:

```bash
sudo poweroff
```

On Node 2, confirm the VIP appears and HTTP succeeds:

```bash
ip address show dev ens18
curl --fail http://192.168.1.10/
sudo journalctl -u keepalived -n 100
```

Start Node 1 and verify whether the intended preemption policy returns the VIP
to the higher-priority node.

## 5. Test failure mode 2: Docker stops on Node 1

With both nodes restored and Node 1 holding the VIP:

```bash
sudo systemctl stop docker
```

The check runs every two seconds and requires two consecutive failures, so Node
1's effective priority should drop after roughly four seconds plus VRRP
convergence time. Verify the VIP and HTTP service on Node 2, then restore Node 1:

```bash
sudo systemctl start docker
docker compose -f /home/debian/devops-scenario/docker-compose.yml up -d
```

Use the normalized repository path rather than the example above.

## 6. Operational checks

```bash
/usr/local/bin/http-check.sh
sudo journalctl -u keepalived --since '15 minutes ago'
sudo tcpdump -ni ens18 proto 112
```

Packet capture is optional and should be limited to an approved diagnostic
window.
