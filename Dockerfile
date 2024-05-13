# syntax=docker/dockerfile:1.2

##########################################################################
# Stage: deps
##########################################################################
FROM docker.io/node:18-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./

# We place the binary in /usr/bin/wunderctl so we can find it without a relative path
ENV WG_COPY_BIN_PATH=/usr/bin/wunderctl
ENV CI=true
# advanced mount options for caching npm even when docker-cache is busted
RUN --mount=type=cache,target=/usr/src/app/.npm \
    : npm install and cache \
    && npm set cache /app/.npm \
    && npm ci --prefer-offline --no-audit

##########################################################################
# Stage: builder
##########################################################################
FROM deps as builder

# Copy the .wundergraph folder to the image
COPY .wundergraph ./.wundergraph

# Listen to all interfaces, 127.0.0.1 might produce errors with ipv6 dual stack
ENV WG_NODE_HOST=0.0.0.0
ENV WG_NODE_PORT=9991
ENV WG_NODE_URL=http://${WG_NODE_HOST}:${WG_NODE_PORT}
ENV WG_NODE_INTERNAL_HOST=127.0.0.1
ENV WG_NODE_INTERNAL_PORT=9993
ENV WG_NODE_INTERNAL_URL=http://${WG_NODE_INTERNAL_HOST}:${WG_NODE_INTERNAL_PORT}
ENV WG_SERVER_HOST=127.0.0.1
ENV WG_SERVER_PORT=9992
ENV WG_SERVER_URL=http://${WG_SERVER_HOST}:${WG_SERVER_PORT}
# We set the public node url as an environment variable so the generated client points to the correct url
# See for node options a https://docs.wundergraph.com/docs/wundergraph-config-ts-reference/configure-wundernode-options and
# for server options https://docs.wundergraph.com/docs/wundergraph-server-ts-reference/configure-wundergraph-server-options
# This is the public node url of the wundergraph node you want to include in the generated client

ARG wg_public_node_url
ENV WG_PUBLIC_NODE_URL=${wg_public_node_url}

RUN wunderctl generate --wundergraph-dir=.wundergraph

##########################################################################
# Stage: dev
##########################################################################
FROM builder AS dev

# Expose only the node, server is private
EXPOSE 9991
CMD wunderctl start --wundergraph-dir=.wundergraph
