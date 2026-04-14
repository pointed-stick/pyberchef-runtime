FROM node:22-bookworm AS node

FROM emscripten/emsdk:3.1.24

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/ /usr/local/

RUN python3 -m pip install --no-cache-dir tomli

ENV PATH=/usr/local/bin:/usr/local/sbin:${PATH}

WORKDIR /workspace
