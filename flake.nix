{
  description = "Main flake";

  nixConfig.bash-prompt = "\\e[0;32m[nix-develop@\\h] \\W>\\e[m ";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        LANG = "C.UTF-8";
        # LANG= "en_US.UTF-8";
        root = ./.;
        inherit (pkgs.lib) optional optionals;

        overlay = (final: prev: {
          yarn = prev.yarn.override {
                  nodejs = final.pkgs.nodejs-18_x;
                };
        });

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };

        pname = "wanderer";

        erlang = pkgs.beam.interpreters.erlang_27;
        elixir = pkgs.beam.packages.erlang_27.elixir_1_17;
        elixir-ls = pkgs.beam.packages.erlang_27.elixir_ls;
        packages = pkgs.beam.packagesWith erlang;
        nodejs = pkgs.nodejs-18_x;
        postgresql = pkgs.postgresql_14;
        yarn = pkgs.yarn;

        # This is opinionated instead of simple using:
        # pkgs.beam.packages.erlang.hex;
        hex = packages.hex;
        MIX_PATH = "${hex}/archives/hex-${hex.version}/hex-${hex.version}/ebin";

        # This is opinionated instead of simple using:
        # pkgs.beam.packages.erlang.rebar3;
        rebar3 = pkgs.beam.packages.erlang_27.rebar3;

        MIX_REBAR3 = "${rebar3}/bin/rebar3";
      in
      with pkgs;
      {
        devShells.default = pkgs.mkShell {
          inherit LANG MIX_PATH MIX_REBAR3 elixir erlang nodejs yarn;
          # use local HOME to avoid global things
          MIX_HOME = ".cache/mix";
          HEX_HOME = ".cache/hex";
          MIX_ENV = "dev";
          # enable IEx shell history
          ERL_AFLAGS = "-kernel shell_history enabled";

          shellHook = ''
          # this allows mix to work on the local directory
          if ! test -d .nix-shell; then
            mkdir .nix-shell
          fi

          export NIX_SHELL_DIR=$PWD/.nix-shell
          # Put the PostgreSQL databases in the project directory.
          export PGDATA=$NIX_SHELL_DIR/db
          export MIX_HOME=$NIX_SHELL_DIR/.mix
          export MIX_ARCHIVES=$MIX_HOME/archives
          export HEX_HOME=$NIX_SHELL_DIR/.hex

          export PATH=$MIX_HOME/bin:$PATH
          export PATH=$HEX_HOME/bin:$PATH
          export PATH=$MIX_HOME/escripts:$PATH
          export LIVEBOOK_HOME=$PWD

          # make hex from Nixpkgs available
          # `mix local.hex` will install hex into MIX_HOME and should take precedence
          export LANG=C.UTF-8
          # keep your shell history in iex
          export ERL_AFLAGS="-kernel shell_history enabled"

          # add your project env vars here, word readable in the nix store.
          # export ENV_VAR="your_env_var"
          ${elixir}/bin/mix --version
          ${elixir}/bin/iex --version
        '';

          buildInputs = [
            nodejs
            yarn
            git
            postgresql
            elixir
            elixir_ls
            pgcli
            flyctl
            glibcLocales
            nixpkgs-fmt
            (pkgs.writeShellScriptBin "pg-stop" ''
              pg_ctl -D $PGDATA -U postgres stop
            '')
            (pkgs.writeShellScriptBin "pg-reset" ''
              rm -rf $PGDATA
            '')
            (pkgs.writeShellScriptBin "pg-setup" ''
              ####################################################################
              # If database is not initialized (i.e., $PGDATA directory does not
              # exist), then set it up. Seems superfluous given the cleanup step
              # above, but handy when one gets to force reboot the iron.
              ####################################################################
              if ! test -d $PGDATA; then
                ######################################################
                # Init PostgreSQL
                ######################################################
                pg_ctl initdb -D  $PGDATA -o "--no-locale --encoding=UTF8"
                #### initdb --locale=C --encoding=UTF8 --auth-local=peer --auth-host=scram-sha-256 > /dev/null || exit
                # initdb --encoding=UTF8 --no-locale --no-instructions -U postgres
                ######################################################
                # PORT ALREADY IN USE
                ######################################################
                # If another `nix-shell` is  running with a PostgreSQL
                # instance,  the logs  will show  complaints that  the
                # default port 5432  is already in use.  Edit the line
                # below with  a different  port number,  uncomment it,
                # and try again.
                ######################################################
                if [[ "$PGPORT" ]]; then
                  sed -i "s|^#port.*$|port = $PGPORT|" $PGDATA/postgresql.conf
                fi
                echo "listen_addresses = ${"'"}${"'"}" >> $PGDATA/postgresql.conf
                echo "unix_socket_directories = '$PGDATA'" >> $PGDATA/postgresql.conf
                echo "CREATE USER postgres WITH PASSWORD 'postgres' CREATEDB SUPERUSER;" | postgres --single -E postgres
              fi
            '')
            (pkgs.writeShellScriptBin "pg-start" ''
              ## # Postgres Fallback using docker
              ## docker run -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:14

              [ ! -d $PGDATA ] && pg-setup

              ####################################################################
              # Start PostgreSQL
              # ==================================================================
              # Setting all  necessary configuration  options via  `pg_ctl` (which
              # is  basically  a wrapper  around  `postgres`)  instead of  editing
              # `postgresql.conf` directly with `sed`. See docs:
              #
              # + https://www.postgresql.org/docs/current/app-pg-ctl.html
              # + https://www.postgresql.org/docs/current/app-postgres.html
              #
              # See more on the caveats at
              # https://discourse.nixos.org/t/how-to-configure-postgresql-declaratively-nixos-and-non-nixos/4063/1
              # but recapping out of paranoia:
              #
              # > use `SHOW`  commands to  check the  options because  `postgres -C`
              # > "_returns values  from postgresql.conf_" (which is  not changed by
              # > supplying  the  configuration options  on  the  command line)  and
              # > "_it does  not reflect  parameters supplied  when the  cluster was
              # > started._"
              #
              # OPTION SUMMARY
              # --------------------------------------------------------------------
              #
              #  + `unix_socket_directories`
              #
              #    > PostgreSQL  will  attempt  to create  a  pidfile  in
              #    > `/run/postgresql` by default, but it will fail as it
              #    > doesn't exist. By  changing the configuration option
              #    > below, it will get created in $PGDATA.
              #
              #   + `listen_addresses`
              #
              #     > In   tandem  with   edits   in  `pg_hba.conf`   (see
              #     > `HOST_COMMON`  below), it  configures PostgreSQL  to
              #     > allow remote connections (otherwise only `localhost`
              #     > will get  authenticated and the rest  of the traffic
              #     > discarded).
              #     >
              #     > NOTE: the  edit  to  `pga_hba.conf`  needs  to  come
              #     >       **before**  `pg_ctl  start`  (or  the  service
              #     >       needs to be restarted otherwise), because then
              #     >       the changes are not being reloaded.
              #     >
              #     > More info  on setting up and  troubleshooting remote
              #     > PosgreSQL connections (these are  all mirrors of the
              #     > same text; again, paranoia):
              #     >
              #     >   + https://stackoverflow.com/questions/24504680/connect-to-postgres-server-on-google-compute-engine
              #     >   + https://stackoverflow.com/questions/47794979/connecting-to-postgres-server-on-google-compute-engine
              #     >   + https://medium.com/scientific-breakthrough-of-the-afternoon/configure-postgresql-to-allow-remote-connections-af5a1a392a38
              #     >   + https://gist.github.com/toraritte/f8c7fe001365c50294adfe8509080201#file-configure-postgres-to-allow-remote-connection-md
              HOST_COMMON="host\s\+all\s\+all"
              sed -i "s|^$HOST_COMMON.*127.*$|host all all 0.0.0.0/0 trust|" $PGDATA/pg_hba.conf
              sed -i "s|^$HOST_COMMON.*::1.*$|host all all ::/0 trust|"      $PGDATA/pg_hba.conf
              #  + `log*`
              #
              #    > Setting up basic logging,  to see remote connections
              #    > for example.
              #    >
              #    > See the docs for more:
              #    > https://www.postgresql.org/docs/current/runtime-config-logging.html

              pg_ctl                                                  \
                -D $PGDATA                                            \
                -l $PGDATA/postgres.log                               \
                -o "-c unix_socket_directories='$PGDATA'"             \
                -o "-c listen_addresses='*'"                          \
                -o "-c log_destination='stderr'"                      \
                -o "-c logging_collector=on"                          \
                -o "-c log_directory='log'"                           \
                -o "-c log_filename='postgresql-%Y-%m-%d_%H%M%S.log'" \
                -o "-c log_min_messages=info"                         \
                -o "-c log_min_error_statement=info"                  \
                -o "-c log_connections=on"                            \
                start
            '')
            (pkgs.writeShellScriptBin "pg-console" ''
              psql --host $PGDATA -U postgres
            '')
          ] ++ optional stdenv.isLinux inotify-tools
            ++ optional stdenv.isDarwin terminal-notifier
            ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
              CoreFoundation
              CoreServices
            ]);

          packages = with pkgs; [ nodejs yarn ];
        };
      });
}
