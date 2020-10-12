defmodule UXID.MixProject do
  use Mix.Project

  @name "UXID"
  @app :uxid
  @description "User eXperience focused IDentifiers"
  @version "0.0.1"

  @deps [
    # Required

    # Development, Documentation, Testing, ...
    {:ex_doc, "~> 0.22", only: :dev},
    {:benchee, "~> 1.0", only: :dev},
    {:benchee_html, "~> 1.0", only: :dev},
    {:ecto_ulid, "~> 0.2", only: :dev}
  ]

  def application(), do: []

  def project() do
    [
      aliases: aliases(),
      app: @app,
      name: @name,
      description: @description,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: @deps,
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: preferred_cli_env(),
      test_coverage: [tool: ExCoveralls],
      docs: docs()
    ]
  end

  # ---------------------------------------------------------------------------
  # Private

  defp aliases() do
    [
      coverage: ["coveralls.html"]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "README",
      source_url: "https://github.com/riddler/uxid",
      # source_root: "impl/ex",
      source_ref: "ex-v#{@version}/impl/ex",
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{
        "UXID Project" => "https://github.com/riddler/uxid",
        "GitHub" => "https://github.com/riddler/uxid/tree/master/impl/ex"
      }
    ]
  end

  defp preferred_cli_env() do
    [
      coverage: :test,
      coveralls: :test,
      "coveralls.html": :test
    ]
  end
end
