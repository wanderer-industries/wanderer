[
  ## don't run tools concurrently
  # parallel: false,

  ## don't print info about skipped tools
  # skipped: false,

  ## always run tools in fix mode (put it in ~/.check.exs locally, not in project config)
  # fix: true,

  ## don't retry automatically even if last run resulted in failures
  # retry: false,

  ## list of tools (see `mix check` docs for a list of default curated tools)
  tools: [
    ## Allow compilation warnings for now (error budget: unlimited warnings)
    {:compiler, "mix compile"},

    ## ...or have command & args adjusted (e.g. enable skip comments for sobelow)
    # {:sobelow, "mix sobelow --exit --skip"},

    ## ...or reordered (e.g. to see output from dialyzer before others)
    # {:dialyzer, order: -1},

    ## Credo with relaxed error budget: max 200 issues
    {:credo, "mix credo --strict --max-issues 200"},

    ## Dialyzer but don't halt on exit (allow warnings)
    {:dialyzer, "mix dialyzer"},

    ## Tests without warnings-as-errors for now
    {:ex_unit, "mix test"},
    {:doctor, false},
    {:npm_test, false},
    {:sobelow, false}

    ## custom new tools may be added (Mix tasks or arbitrary commands)
    # {:my_task, "mix my_task", env: %{"MIX_ENV" => "prod"}},
    # {:my_tool, ["my_tool", "arg with spaces"]}
  ]
]
