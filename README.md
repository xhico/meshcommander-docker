# MeshCommander in Docker

Run [MeshCommander](https://www.meshcommander.com/) (Intel AMT / vPro console) without
installing Node.js on your Mac. Node lives only inside the image.

This image installs the published npm **server** package `meshcommander`, which serves
the web UI and provides the WebSocket→AMT relay on port 3000. (It is *not* the NW.js
desktop app from the GitHub source — that's a different packaging.)

> [!IMPORTANT]
> **The container — not your browser — is what connects to your AMT device.**
> MeshCommander's server opens the TCP session to the AMT host, so the container must be
> able to reach it on your LAN. Running it on a **Linux Docker host on the same LAN** is
> the most reliable setup. On macOS it also works, but containers run inside a VM, which
> adds a layer worth understanding if connections fail — see
> [AMT device connectivity](#reaching-your-amt-devices) below.

## Run (pull the pre-built image — recommended)

The image is published to GHCR by CI, so you don't need to build anything:

```bash
docker run -d --name meshcommander -p 3000:3000 \
  --restart unless-stopped ghcr.io/xhico/meshcommander:latest
```

Or with compose (the default `docker-compose.yml` pulls from GHCR):

```bash
docker compose up -d
```

Then open `http://<host>:3000`.

**Portainer (Git stack):** point a Repository stack at this repo with compose path
`docker-compose.yml`. It only *pulls* the image — no in-app build, which avoids
Portainer's BuildKit build-session error (`http2: frame too large`).

## Build it yourself (optional)

If you'd rather build from source instead of pulling:

```bash
docker compose -f docker-compose.build.yml up -d --build
# or plain docker:
docker build -t meshcommander:local .
docker run -d --name meshcommander -p 3000:3000 --restart unless-stopped meshcommander:local
```

## Why `--any` matters

MeshCommander binds to `127.0.0.1` by default. Inside a container that makes it
unreachable through `-p 3000:3000`. The image's start command passes `--any` so it
binds `0.0.0.0`. If you override the command, keep `--any`.

## Reaching your AMT devices

The container needs network access to your AMT hosts (LAN, TCP **16992** plaintext /
**16993** TLS, plus **16994/16995** for redirection). Because MeshCommander's server is
the one that opens the TCP connection to the AMT box, **the container — not your
browser — must be able to reach the AMT host.**

### Linux Docker host on the LAN (most reliable)

On a Linux Docker host that sits on the same LAN as your AMT devices, bridge networking
NATs straight onto the physical LAN and reaches the AMT ports with no extra
configuration. If you want one setup that just works, use this.

### macOS (Colima / Docker Desktop)

On macOS containers don't run natively — they run inside a Linux VM. In normal operation
a container on **Colima** *can* reach LAN hosts, including AMT devices, with default
networking. So running this on a Mac is viable.

The VM does add a layer that can fail in ways a Linux host won't, so if the web UI loads
but MeshCommander can't connect to your AMT box, work through the following.

#### Troubleshooting: container can't reach the AMT host

**1. Check from the Mac itself first.** This separates a container problem from an AMT
problem:

```bash
nc -zv <amt-host> 16992
```

If the Mac can't reach it either, the issue is AMT/the network, not Docker — AMT
silently dropping off the network is common (see [AMT reachability](#amt-reachability)).

**2. If the Mac reaches it but the container doesn't, restart the VM.** A long-running
Colima VM can end up in a stale network state where a container gets `ECONNREFUSED` for
a specific LAN host that the Mac reaches fine. Restarting clears it:

```bash
colima stop && colima start
```

This was the actual cause of a lengthy debugging session behind this repo — a container
could reach the default gateway and the internet, but not one particular LAN host, until
Colima was restarted.

**3. Optional — give the VM its own reachable address.** Not required for outbound LAN
access, but available if you want the VM addressable on your network:

```bash
colima stop && colima start --network-address
```

`colima list` will then show an IP in the `ADDRESS` column. Note this setting persists in
`~/.colima/<profile>/colima.yaml`; a plain `colima start` will *not* undo it, and neither
does `--network-address=false` — use `colima start --edit` and set `address: false`.

> Behaviour on **Docker Desktop** and **Rancher Desktop** was not tested for this
> project; their VM networking differs from Colima's, so treat the above as
> Colima-specific.

## AMT reachability

Before blaming Docker, confirm AMT is actually listening. Intel AMT runs on the
Management Engine, independent of the host OS, and can silently stop answering while the
machine itself stays perfectly reachable:

```bash
nc -zv <amt-host> 16992     # AMT plaintext
nc -zv <amt-host> 22        # host OS, for comparison
```

If the OS ports answer but 16992/16993 are refused, AMT itself is down — no container
change will help.

**Test from another machine, never from the AMT host itself.** Traffic from a host to its
own IP is routed over loopback (`ip route get <its-own-ip>` shows `dev lo`) and never
reaches the ME on the wire, so it always looks closed.

Things that actually fix a silent AMT, in order:

1. **Energy-Efficient Ethernet (EEE) on the shared NIC.** If AMT shares the onboard NIC
   with the OS, EEE's low-power idle can make the ME drop off the network intermittently
   — it works after a cold boot, then goes quiet. Disabling it revived AMT immediately in
   our case:
   ```bash
   ethtool --show-eee <nic>            # "EEE status: enabled - active" is the smoking gun
   ethtool --set-eee <nic> eee off
   ```
   Persist it (Debian/Proxmox) so it survives reboots:
   ```bash
   printf '#!/bin/sh\n[ "$IFACE" = "<nic>" ] && /sbin/ethtool --set-eee <nic> eee off\nexit 0\n' \
     > /etc/network/if-up.d/disable-eee && chmod +x /etc/network/if-up.d/disable-eee
   ```
2. **Full power drain.** A soft reboot does *not* reset the Management Engine. Shut down,
   unplug for ~60 s, boot.
3. **MEBx / BIOS.** Confirm AMT is provisioned with network access activated, and that
   the ME keeps power in all states (disable deep sleep / ErP).

## Manage

```bash
docker logs -f meshcommander     # view logs
docker stop meshcommander        # stop
docker start meshcommander       # start again
docker rm -f meshcommander       # remove container
docker rmi meshcommander:local   # remove image (removes all Node traces)
```

## Change the port

Map a different host port, e.g. serve on 8080:

```bash
docker run -d --name meshcommander -p 8080:3000 meshcommander:local
```

## Credits

All credit for MeshCommander itself goes to **Ylian Saint-Hilaire** and Intel. This
repo is only a thin Docker wrapper — the idea and all the actual software come from the
original project:

- Original source: <https://github.com/Ylianst/MeshCommander>
- Project site: <https://www.meshcommander.com/>
- npm package this image installs: <https://www.npmjs.com/package/meshcommander>

This wrapper just packages the published `meshcommander` npm server into a container so
it runs without Node.js on the host.
