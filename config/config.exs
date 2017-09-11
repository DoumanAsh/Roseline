# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :roseline, Db.Repo,
  adapter: EctoMnesia.Adapter

config :roseline, bots: [
  %{:server => "irc.rizon.net", :port => 6697,
    :nick => "Roseline", :user => "Roseline", :name => "Roseline",
    :channel => ["#vndis"], :ssl? => true}
]

config :roseline, ecto_repos: [Db.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

config :mnesia,
  dir: 'priv/data/mnesia'

extra_config = "#{Mix.env}.exs"
if File.exists?(Path.join(__DIR__, extra_config)) do
  import_config(extra_config)
end
