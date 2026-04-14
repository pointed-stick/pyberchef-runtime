FROM node:22-bookworm AS node

FROM emscripten/emsdk:3.1.24

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    perl \
    python3-pip \
    python3-venv \
    pkg-config \
    tcl-dev \
    tk-dev \
    uuid-dev \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/ /usr/local/

RUN python3 -m pip install --upgrade "pip<25" setuptools wheel build tomli

ENV PATH=/usr/local/bin:/usr/local/sbin:${PATH}

WORKDIR /workspace
