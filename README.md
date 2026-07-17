# MeshCommander in Docker

Run [MeshCommander](https://www.meshcommander.com/) (Intel AMT / vPro console) without
installing Node.js on your Mac. Node lives only inside the image.

This image installs the published npm **server** package `meshcommander`, which serves
the web UI and provides the WebSocket→AMT relay on port 3000. (It is *not* the NW.js
desktop app from the GitHub source — that's a different packaging.)

## Build

```bash
cd meshcommander-docker
docker build -t meshcommander:local .
```

## Run

```bash
docker run -d --name meshcommander -p 3000:3000 --restart unless-stopped meshcommander:local
```

Then open <http://localhost:3000>.

Or with compose (build + run in one step):

```bash
docker compose up -d --build
```

## Why `--any` matters

MeshCommander binds to `127.0.0.1` by default. Inside a container that makes it
unreachable through `-p 3000:3000`. The image's start command passes `--any` so it
binds `0.0.0.0`. If you override the command, keep `--any`.

## Reaching your AMT devices

The container needs network access to your AMT hosts (LAN, TCP **16992** plaintext /
**16993** TLS). On Docker Desktop for macOS, bridge networking (default) can reach LAN
IPs outbound, so this normally works. `--network host` is unavailable on Mac, so keep
the `-p 3000:3000` mapping for the UI.

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
