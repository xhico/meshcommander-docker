# MeshCommander in Docker

Run [MeshCommander](https://www.meshcommander.com/) (Intel AMT / vPro console) without
installing Node.js on your Mac. Node lives only inside the image.

This image installs the published npm **server** package `meshcommander`, which serves
the web UI and provides the WebSocket→AMT relay on port 3000. (It is *not* the NW.js
desktop app from the GitHub source — that's a different packaging.)

> [!WARNING]
> **On macOS, this can't reach AMT devices on your LAN with default container
> networking.** Mac container runtimes (Colima, Docker Desktop, Rancher Desktop) run
> containers inside a Linux VM behind **user-mode NAT**, which reaches the internet and
> your default gateway but **not other physical devices on your LAN** — with bridge
> networking, with `--network host`, and regardless of the macOS firewall. The web UI
> loads fine, but the AMT relay never connects to your target (`ECONNREFUSED`), even
> though the Mac itself reaches the AMT host.
> **On Colima, fix it with `colima start --network-address`** (verified working).
> On Docker Desktop there's no equivalent — run it on a Linux Docker host on the same
> LAN instead (a mini PC, NAS, Raspberry Pi, or a bridged LXC/VM).
> See [AMT device connectivity](#reaching-your-amt-devices) below.

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

### Linux Docker host (works)

On a Linux Docker host that sits on the same LAN as your AMT devices, plain bridge
networking NATs straight onto the physical LAN and reaches the AMT ports with no extra
configuration. This is the supported setup.

### macOS with default container networking (does NOT work for LAN AMT hosts)

On macOS, containers don't run natively — Colima, Docker Desktop and Rancher Desktop all
run them inside a Linux VM. By default that VM uses **user-mode ("slirp") networking**,
which forwards internet traffic and the Mac's default gateway but **not arbitrary peer
devices on your subnet**. Verified behaviour reaching an AMT host at, e.g.,
`<amt-host>:16992` (tested on **Colima**; Docker Desktop behaves the same way):

| From | Result |
| --- | --- |
| The Mac itself (native process) | ✅ OPEN |
| Container, bridge networking | ❌ `ECONNREFUSED` |
| Container, `--network host` | ❌ `ECONNREFUSED` |
| macOS firewall disabled | ❌ no change |

`--network host` does not help: on macOS it puts the container in the **VM's** network
namespace, not your Mac's. You can see this from inside the container — it reports an
address on the VM's private range (e.g. `192.168.x.x`) rather than your LAN address.

**Recommended fix: run the container on a Linux Docker host on the same LAN.**

#### Working fix on Colima: `--network-address` ✅

Unlike Docker Desktop, **Colima can reach LAN peers** — start it with a `vmnet`
address:

```bash
colima stop
colima start --network-address
```

This adds a second interface (`col0`) to the VM on the macOS `vmnet` network, and
containers can then reach devices on your physical LAN. **Verified** — with the flag,
the same container that previously got `ECONNREFUSED` reaches the AMT host:

| Target from inside a container | Default networking | With `--network-address` |
| --- | --- | --- |
| `<amt-host>:16992` (AMT) | ❌ `ECONNREFUSED` | ✅ OPEN |
| `<amt-host>:8006` (other LAN service) | ❌ `ECONNREFUSED` | ✅ OPEN |
| internet | ✅ OPEN | ✅ OPEN |

Confirm the VM picked up the address — `colima list` should show one in the `ADDRESS`
column:

```
PROFILE   STATUS    ARCH      RUNTIME   ADDRESS
default   Running   aarch64   docker    192.168.64.2
```

So on **Colima** you can run this container on your Mac. On **Docker Desktop**, there is
no equivalent — use a Linux host on the LAN.

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
