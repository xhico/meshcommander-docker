# MeshCommander in Docker

Run [MeshCommander](https://www.meshcommander.com/) (Intel AMT / vPro console) without
installing Node.js on your Mac. Node lives only inside the image.

This image installs the published npm **server** package `meshcommander`, which serves
the web UI and provides the WebSocket→AMT relay on port 3000. (It is *not* the NW.js
desktop app from the GitHub source — that's a different packaging.)

> [!WARNING]
> **Do not run this on Docker Desktop for macOS if your AMT devices are on the LAN.**
> Containers on Docker Desktop for Mac run inside a hidden Linux VM and **cannot reach
> other physical devices on your Mac's LAN** — not with bridge networking, not with
> `--network host`, regardless of the macOS firewall. The web UI loads fine, but the
> AMT relay can never connect to your target (`ECONNREFUSED`), even though your Mac
> itself reaches the AMT host. **Run it on a Linux Docker host that sits on the same
> LAN as your AMT devices instead** (a mini PC, NAS, Raspberry Pi, or a bridged
> LXC/VM). See [AMT device connectivity](#reaching-your-amt-devices) below.

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

### Docker Desktop for macOS (does NOT work for LAN AMT hosts)

Containers on Docker Desktop for Mac run inside a hidden `LinuxKit` VM. That VM only
reaches your LAN through Docker's NAT proxy, which forwards internet traffic and the
Mac's gateway but **not arbitrary peer devices on your subnet**. Verified behaviour
reaching an AMT host at, e.g., `<amt-host>:16992`:

| From | Result |
| --- | --- |
| Your Mac (native) | ✅ OPEN |
| Container, bridge networking | ❌ `ECONNREFUSED` |
| Container, `--network host` | ❌ `ECONNREFUSED` (host = the internal Docker VM, not your Mac) |
| macOS firewall disabled | ❌ no change |

`--network host` on macOS puts the container in the *VM's* network namespace, not your
Mac's, so it does not help. There is no Docker Desktop setting that bridges a container
onto your real LAN. **Move the container to a Linux host on the LAN.**

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
