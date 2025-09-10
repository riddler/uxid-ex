defmodule UXID.MixProject do
  use Mix.Project

  @name "UXID"
  @app :uxid
  @description "Generates UX focused IDs like: usr_01epey2p06tr1rtv07xa82zgjj (K-sortable with prefix - like Stripe)"
  @version "2.1.0"
  @source_url "https://github.com/riddler/uxid-ex"

  @deps [
    # Required

    # Optional
    {:ecto, "~> 3.12", optional: true},

    # Development, Documentation, Testing, ...
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:ex_doc, "~> 0.23", only: :dev},
    {:benchee, "~> 1.0", only: :dev},
    {:benchee_html, "~> 1.0", only: :dev},
    {:ecto_ulid, "~> 0.2", only: :dev, optional: true}
  ]

  def application(), do: [extra_applications: [:crypto]]

  def project() do
    [
      aliases: aliases(),
      app: @app,
      name: @name,
      description: @description,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: @deps,
      elixirc_options: [warnings_as_errors: true],
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: preferred_cli_env(),
      test_coverage: [tool: ExCoveralls],

      # Exclude optional dependencies
      xref: [exclude: Ecto.ParameterizedType],

      # Docs
      source_url: @source_url,
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
      name: "UXID",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/uxid",
      main: "readme",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp package() do
    [
      name: @app,
      files: ~w(lib/uxid* mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["UXID Team"]
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
