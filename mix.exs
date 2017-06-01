defmodule Aru.Mixfile do
  use Mix.Project

  def project do
    [app: :aru,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  def application do
    [
      mod: {Aru, []},
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
      {:kaguya, git: "git://github.com/Luminarys/Kaguya"},
      {:elivndb, "~> 0.2.1"},
      {:credo, "~> 0.7.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
