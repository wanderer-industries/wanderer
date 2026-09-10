# Pins Elixir to the .tool-versions value (1.17.3) instead of the floating
# 1.17 tag, which could drift to a different Elixir patch. This matters because
# _build is shared with the host via the /app bind. Note the OTP suffix pins
# only the major (26); the Erlang patch may still differ from .tool-versions'
# 26.2.5.5, since the official images publish no patch-level tag.
FROM elixir:1.17.3-otp-26

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ENV DEBIAN_FRONTEND=noninteractive

# Install OS packages, Node.js (via nodesource), yarn, and gh CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo \
        curl \
        make \
        git \
        git-lfs \
        bash \
        zsh \
        build-essential \
        ca-certificates \
        gnupg \
        jq \
        ripgrep \
        tree \
        lsof \
        htop \
        less \
        vim \
        locales \
        net-tools \
        netcat-openbsd \
        procps \
        inotify-tools \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generate UTF-8 locale (some Elixir libs are encoding-sensitive)
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create non-root user with passwordless sudo and zsh as login shell
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Persistent shell history across container rebuilds
RUN mkdir -p /commandhistory && chown -R $USERNAME:$USERNAME /commandhistory

# Allow git operations on the bind-mounted workspace
RUN git config --system --add safe.directory /app

USER $USERNAME

RUN mix local.hex --force && mix local.rebar --force

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins (autosuggestions + syntax highlighting)
RUN git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-/home/$USERNAME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        ${ZSH_CUSTOM:-/home/$USERNAME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# .zshrc with oh-my-zsh, persistent history, and project aliases
RUN printf '%s\n' \
        'export ZSH="$HOME/.oh-my-zsh"' \
        'ZSH_THEME="robbyrussell"' \
        'plugins=(git mix docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)' \
        'source $ZSH/oh-my-zsh.sh' \
        '' \
        '# Persistent history (mounted volume)' \
        'HISTFILE=/commandhistory/.zsh_history' \
        'HISTSIZE=10000' \
        'SAVEHIST=10000' \
        'setopt appendhistory' \
        'setopt sharehistory' \
        'setopt hist_ignore_dups' \
        '' \
        '# Aliases' \
        'alias ll="ls -la"' \
        'alias la="ls -A"' \
        'alias gs="git status"' \
        'alias gd="git diff"' \
        '' \
        '# Elixir/Phoenix aliases' \
        'alias mt="mix test"' \
        'alias mc="mix compile"' \
        'alias mf="mix format"' \
        'alias ms="iex -S mix phx.server"' \
        'alias deps="mix deps.get"' \
        '' \
        '# User-local binaries (tools installed via a compose override, etc.)' \
        'export PATH="$HOME/.local/bin:$PATH"' \
        '' \
        'export EDITOR=vim' \
        'cd /app 2>/dev/null || true' \
        > /home/$USERNAME/.zshrc

WORKDIR /app

ENV DEBIAN_FRONTEND=dialog
