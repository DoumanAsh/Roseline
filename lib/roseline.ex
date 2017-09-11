defmodule Roseline do
  @moduledoc """
  Roseline Application
  """
  use Application

  ## Module variables
  @name __MODULE__
  @cache_name :vndb_api

  ## Cache related
  # VNDB rarely updates its data, especially for old titles.
  # Therefore let's store cache up to 7 days.
  @default_ttl :timer.hours(7 * 24)
  @cache_limit %Cachex.Limit{limit: 500, policy: Cachex.Policy.LRW, reclaim: 0.25}
  @cache_options [
    default_ttl: @default_ttl,
    ttl_interval: @default_ttl,
    limit: @cache_limit,
    disable_ode: true,
    fallback: &EliVndb.Client.get/1
  ]
  @cache_dir Path.absname("priv/data/cache")

  ## Module code
  @doc "Used cache name"
  def cache_name, do: @cache_name

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(EliVndb.Client, []),
      worker(Cachex, [@cache_name, @cache_options]),
      supervisor(Db.Repo, [])
    ]

    bots = Enum.map(Application.get_env(:roseline, :bots), &(worker(Roseline.Irc.Bot, [&1])))

    Supervisor.start_link(children ++ bots, [strategy: :one_for_one, name: @name])
  end
end
