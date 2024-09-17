with import <nixpkgs> { };
let
  pname = "wanderer";
  version = "0.0.0";
  src = ./.; #FIXME once uploaded to repository, change the source
  packages = beam.packagesWith beam.interpreters.erlang_25;
  erlang = beam.interpreters.erlang_25;
  elixir = beam.packages.erlang_25.elixir_1_16;

  mixFodDeps = packages.fetchMixDeps {
    pname = "mix-deps-${pname}";
    inherit src version elixir;
    hash = "sha256-rILIBMHOHGyCuog8ZtmQAVCiHqn6b7CBrSMNBeSycNM=";
  };

  # yarnDeps = mkYarnModules {
  #   pname = "${pname}-yarn-deps";
  #   inherit version;
  #   packageJSON = ./apps/portal_web/assets/package.json;
  #   yarnLock = ./apps/portal_web/assets/yarn.lock;
  #   yarnNix = ./yarn.nix;
  #   preBuild = ''
  #     mkdir -p tmp/deps
  #     cp -r ${mixFodDeps}/phoenix tmp/deps/phoenix
  #     cp -r ${mixFodDeps}/phoenix_html tmp/deps/phoenix_html
  #   '';
  # };
in
packages.mixRelease {
  inherit pname version src elixir erlang mixFodDeps;

  nativeBuildInputs = [ nodejs ];

  # tportal is an umbrella app
  # override configurePhase to not skip umbrella children
  configurePhase = ''
    runHook preConfigure
    mix deps.compile --no-deps-check
    runHook postConfigure
  '';

  postBuild = ''
    # for external task you need a workaround for the no deps check flag
    # https://github.com/phoenixframework/phoenix/issues/2690
    mix do deps.loadpaths --no-deps-check, phx.digest
    mix phx.digest --no-deps-check
  '';
}
