defmodule Web.MixProject do
  use Mix.Project

  def project do
    [
      app: :web,
      version: String.trim(File.read!("../../VERSION")),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Web.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools,
        :dialyzer
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Umbrella deps
      {:domain, in_umbrella: true},

      # Phoenix/Plug deps
      {:phoenix, "~> 1.7.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:plug_cowboy, "~> 2.7"},
      {:gettext, "~> 0.20"},
      {:remote_ip, "~> 1.0"},

      # CLDR and unit conversions
      {:ex_cldr_dates_times, "~> 2.13"},
      {:ex_cldr_numbers, "~> 2.31"},
      {:sizeable, "~> 1.0"},

      # Asset pipeline deps
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},

      # Observability and debugging deps
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:recon, "~> 2.5"},
      {:observer_cli, "~> 1.7"},

      # Mailer deps
      {:phoenix_swoosh, "~> 1.0"},
      {:gen_smtp, "~> 1.0"},

      # Observability
      {:opentelemetry_cowboy, "~> 0.3.0"},
      {:opentelemetry_liveview, "~> 1.0.0-rc.4"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:nimble_options, "~> 1.0", override: true},

      # Other deps
      {:jason, "~> 1.2"},
      {:file_size, "~> 3.0.1"},
      {:nimble_csv, "~> 1.2"},

      # Test deps
      {:floki, ">= 0.30.0", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:bureaucrat, "~> 0.2.9", only: :test},
      {:wallaby, "~> 0.30.0", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:mix_audit, "~> 2.1", only: [:dev, :test]},
      {:sobelow, "~> 0.12", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": [
        "cmd cd assets && CI=true pnpm i",
        "tailwind.install --if-missing",
        "esbuild.install --if-missing"
      ],
      "assets.build": ["tailwind web", "esbuild web"],
      "assets.deploy": ["tailwind web --minify", "esbuild web --minify", "phx.digest"],
      "ecto.seed": ["ecto.create", "ecto.migrate", "run ../domain/priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "phx.server": ["ecto.create --quiet", "ecto.migrate", "phx.server"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
