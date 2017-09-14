defmodule Roseline.Mixfile do
  use Mix.Project

  def project do
    [app: :roseline,
     version: "0.2.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  def application do
    [
      mod: {Roseline, []},
      extra_applications: [
        :logger,
      ]
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp deps do
    [
      {:cachex, "~> 2.1"},
      {:ecto, "~> 2.1"},
      {:ecto_mnesia, "~> 0.9"},

      {:exirc, git: "https://github.com/bitwalker/exirc.git", tag: "master"},

      {:elivndb, "~> 0.2"},

      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
