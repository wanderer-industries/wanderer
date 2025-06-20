defmodule Mix.Tasks.Openapi.Export do
  @moduledoc """
  Export OpenAPI specification to a JSON file for version comparison and documentation.

  ## Usage

      mix openapi.export [--output path/to/spec.json]

  ## Options

    * `--output` - Output file path (defaults to `priv/static/openapi.json`)
    * `--format` - Output format: json (defaults to json)

  ## Examples

      # Export to default location
      mix openapi.export

      # Export to custom location
      mix openapi.export --output docs/api/v1/spec.json

      # Export with explicit format
      mix openapi.export --format json
  """

  use Mix.Task

  @shortdoc "Export OpenAPI specification to file"

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [output: :string, format: :string],
        aliases: [o: :output, f: :format]
      )

    output_path = opts[:output] || "priv/static/openapi.json"

    # Safe format parsing - only allow predefined formats
    _format =
      case opts[:format] || "json" do
        "json" -> :json
        other -> Mix.raise("Unknown format: #{other}. Supported formats: json")
      end

    # Ensure we compile everything needed
    Mix.Task.run("compile", ["--force"])
    
    # Start the application if not already started
    Application.ensure_all_started(:wanderer_app)

    # Get the OpenAPI spec
    spec = WandererAppWeb.ApiSpec.spec()

    # Validate output path to prevent path traversal
    expanded_path = Path.expand(output_path)
    cwd = File.cwd!()
    
    unless String.starts_with?(expanded_path, cwd) do
      Mix.raise("Output path must be within the current directory")
    end
    
    if String.contains?(output_path, "..") do
      Mix.raise("Output path cannot contain '..' directory traversal")
    end

    # Ensure output directory exists
    expanded_path
    |> Path.dirname()
    |> File.mkdir_p!()

    # Write the spec as JSON
    json =
      spec
      |> OpenApiSpex.OpenApi.to_map()
      |> Jason.encode!(pretty: true)

    File.write!(expanded_path, json)
    Mix.shell().info("OpenAPI spec exported to #{output_path}")
  end
end
