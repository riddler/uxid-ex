defmodule UXID.MixProject do
  use Mix.Project

  @name "UXID"
  @app :uxid
  @description "Generates UX focused IDs like: usr_01epey2p06tr1rtv07xa82zgjj (K-sortable with prefix - like Stripe)"
  @version "2.6.0"
  @source_url "https://github.com/riddler/uxid-ex"

  @deps [
    # Required

    # Optional
    {:ecto, "~> 3.12", optional: true},

    # Development, Documentation, Testing, ...
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:excoveralls, "~> 0.18.5", only: :test},
    {:ex_quality, "~> 0.6", only: :dev, runtime: false},
    {:ex_doc, "~> 0.34", only: :dev},
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

      # Dialyzer: cache the PLT in-repo (CI-friendly) and include the optional
      # Ecto app so the ParameterizedType behaviour callbacks type-check.
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts",
        plt_add_apps: [:ecto, :mix]
      ],

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
      extras: [
        "README.md",
        "guides/sizes.md",
        "guides/ecto.md",
        "guides/monotonic.md",
        "guides/deterministic.md",
        "guides/registry.md",
        "guides/configuration.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: ~r/guides\//
      ],
      groups_for_modules: [
        Registry: [UXID.Registry, UXID.Registered]
      ]
    ]
  end

  defp package() do
    [
      name: @app,
      files: ~w(lib/uxid* mix.exs README.md LICENSE CHANGELOG.md guides),
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
