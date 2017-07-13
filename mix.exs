defmodule Roseline.Mixfile do
  use Mix.Project

  def project do
    [app: :roseline,
     version: "0.1.0",
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
      test: "test --no-start"
    ]
  end

  defp deps do
    [
      {:cachex, "~> 2.1"},
      {:ecto, "~> 2.0"},
      {:ecto_mnesia, "~> 0.9.0"},
      {:kaguya, "~> 0.6.4"},
      {:elivndb, "~> 0.2.3"},
      {:credo, "~> 0.7.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
