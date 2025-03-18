FROM elixir:1.17-otp-27

RUN apt install -yq curl gnupg
# Install OS packages and Node.js (via nodesource),
# plus inotify-tools and yarn
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    make \
    git \
    bash \
    build-essential \
    ca-certificates \
    jq \
    vim \
    net-tools \
    procps \
    # Optionally add any other tools you need, e.g. vim, wget...
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y --no-install-recommends nodejs inotify-tools \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt --fix-broken install

RUN mix local.hex --force

WORKDIR /app
