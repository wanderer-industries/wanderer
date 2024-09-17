FROM elixir:1.16-otp-25

RUN apt update -yq
RUN apt install -yq curl gnupg mc inotify-tools
RUN apt --fix-broken install
RUN apt remove -y nodejs nodejs-doc
RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash -
RUN apt install -y nodejs
RUN npm install --global yarn

RUN mix local.hex --force

WORKDIR /app
