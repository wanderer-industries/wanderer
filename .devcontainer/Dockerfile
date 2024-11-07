FROM elixir:1.17-otp-27

RUN apt install -yq curl gnupg
RUN apt --fix-broken install

RUN mix local.hex --force

WORKDIR /app
