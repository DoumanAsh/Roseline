defmodule Aru.Mixfile do
  use Mix.Project

  def project do
    [app: :aru,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [
      extra_applications: [
        :logger,
        :kaguya
      ]
    ]
  end

  defp deps do
    [
      {:kaguya, "~> 0.5.1"},
      {:elivndb, "~> 0.2.0"},
      {:credo, "~> 0.7.4", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
