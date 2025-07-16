FROM elixir:1.17-otp-27-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl ca-certificates sudo make jq \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest yarn @anthropic-ai/claude-code \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix deps.get && mix deps.compile

COPY . .

FROM elixir:1.17-otp-27-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash vim nano git curl wget ca-certificates \
      build-essential make jq htop tree zip unzip \
      net-tools procps iputils-ping telnet netcat-openbsd \
      inotify-tools \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn @anthropic-ai/claude-code \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && useradd -m vscode && mkdir /app && chown vscode:vscode /app

USER vscode
WORKDIR /app

COPY --chown=vscode:vscode --from=builder /app /app

ENV MIX_ENV=dev \
    ERL_AFLAGS="-kernel shell_history enabled"

