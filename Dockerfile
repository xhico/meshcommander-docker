# MeshCommander in a container.
# Node.js lives ONLY inside this image — your host stays Node-free.
#
# MeshCommander is Intel AMT / vPro management console by Ylian Saint-Hilaire.
# We install the published npm server package (NOT the NW.js desktop source).

FROM node:20-alpine

# Pin the version so builds are reproducible. Latest published tag is 0.9.5-a.
ARG MESHCOMMANDER_VERSION=0.9.5-a

# Deps (express, express-ws, minimist) are pure JS — no native build tools needed.
RUN npm install -g "meshcommander@${MESHCOMMANDER_VERSION}" \
    && npm cache clean --force

# Drop root — run as the image's built-in unprivileged user.
USER node

# Web UI + AMT WebSocket relay listens here.
EXPOSE 3000

# --any : bind 0.0.0.0 instead of the default 127.0.0.1, so the mapped
#         container port (-p 3000:3000) is actually reachable from your host.
# --port: keep it explicit / easy to change.
CMD ["meshcommander", "--any", "--port", "3000"]
