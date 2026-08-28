# High Availability & Failover — Approach

## Goal

Present one stable service address, prefer Node 1 during normal operation, and
move that address to Node 2 when Node 1 is unreachable or its local web service
fails.

## Control flow

```text
                         clients
                            |
                 192.168.1.10:80 (VIP)
                            |
              +-------------+-------------+
              |                           |
       Node 1 priority 150          Node 2 priority 100
       healthy: 150                 healthy: 100
       failed check: 90             failed check: 40
              |                           |
       curl local port 80           curl local port 80
              |                           |
          Docker/Nginx                  Docker/Nginx
```

Keepalived advertisements elect the highest available priority. Node 1 is the
normal owner at 150. Its `weight -60` health penalty lowers it to 90, allowing
healthy Node 2 at 100 to take over. If Node 1 powers off, its advertisements stop
entirely and Node 2 becomes master after the VRRP timeout.

## Why Keepalived and VRRP

VRRP is a small, established active/passive mechanism for moving an IP address
on a shared Layer 2 network. It reacts independently of DNS caches, needs no
external load balancer, and maps directly to the two required failure modes.

It is not application replication and does not synchronize HTML, configuration,
logs, or Docker images. Both nodes must already be able to serve equivalent
content before failover is useful.

## Health-check choice

The script requests `http://127.0.0.1/`, exercising host port 80, Docker's port
publication, the running container, Nginx, and an HTTP success response. It
therefore catches more than `systemctl is-active docker`: a running Docker daemon
with a stopped or broken Nginx container is also unhealthy.

A two-second interval and two-failure threshold balance detection speed against
a single transient request failure. The symmetric two-success recovery threshold
reduces immediate flapping when service returns.

For a larger application, use a dedicated lightweight health endpoint that
checks only dependencies required to serve safe traffic. A deep check can cause
cascading failover during a shared dependency outage.

## Public-address interpretation

The checked-in VIP is an RFC 1918 private address. It can be the stable address
inside a LAN, with a router or firewall mapping a public IP to it. Standard VRRP
does not make a private VM address Internet-routable and often does not work on
cloud networks that block multicast or address movement. In those environments,
the cloud load balancer or floating-IP API is the correct failover mechanism.

## Preemption and recovery

Because Node 1 has higher priority and `nopreempt` is not configured, it should
take the VIP back after its health check recovers. This restores the preferred
topology automatically but causes another connection interruption. Adding
`nopreempt` would reduce movement by leaving a recovered cluster on Node 2 until
the next failover or operator action. The selected behavior should match the
service's stability requirements.

## Split-brain and fencing

If VRRP traffic is blocked while both hosts can serve clients, both can believe
they are master. Duplicate address ownership can produce intermittent traffic
and ARP instability. Controls include:

- allow VRRP only between the two known host addresses;
- monitor duplicate-address and master-transition events;
- keep both nodes on the same reliable Layer 2 segment;
- test firewall changes before rollout;
- use a platform load balancer or fencing mechanism where Layer 2 assumptions do
  not hold.

Password authentication in VRRP is not strong encryption; it mainly prevents
accidental participation. Restricting protocol 112 at the network boundary is
more important, and example secrets must be replaced.

## Expected failure behavior

| Event | Election effect | Expected owner |
|---|---|---|
| Both web services healthy | 150 beats 100 | Node 1 |
| Node 1 powers off | Node 1 advertisements disappear | Node 2 |
| Docker or HTTP stops on Node 1 | Node 1 drops to effective priority 90 | Node 2 |
| Node 1 recovers and preemption remains enabled | Node 1 returns to 150 | Node 1 |
| Both web checks fail | Relative priority still elects a host, but service is unavailable | Alert; no healthy backend |

The last row is important: VRRP chooses an address owner, not a guarantee of
application health. Monitoring must alert when neither backend can serve.

## Alternatives considered

- **DNS failover:** works across networks but is slowed by resolver caching and
  needs an external health authority.
- **HAProxy on one host:** enables richer checks but makes that proxy a new
  single point of failure unless it is also made redundant.
- **Managed load balancer/floating IP:** preferred in supported clouds, but adds
  platform dependency and cost.
- **Active/active routing:** can improve utilization, but adds state, consistency,
  and troubleshooting complexity unnecessary for this static service.
