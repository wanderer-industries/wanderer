ARG BUILDER_IMAGE="wandererltd/build-base:latest"
ARG RUNNER_IMAGE="wandererltd/runner-base:latest"

FROM ${BUILDER_IMAGE} as builder

# prepare build dir
WORKDIR /app

# set build ENV
ENV MIX_ENV="prod"

# Set ERL_FLAGS for ARM compatibility
ENV ERL_FLAGS="+JPperf true"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN rm -Rf _build deps && mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/
COPY rel rel

RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

WORKDIR "/app"
COPY --chmod=755 ./rel/docker-entrypoint.sh /app/entrypoint.sh
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/wanderer_app ./

USER nobody

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["run"]
