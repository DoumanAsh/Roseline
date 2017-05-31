# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :aru, Db.Repo,
  adapter: EctoMnesia.Adapter

config :aru, ecto_repos: [Db.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

config :mnesia,
  dir: 'priv/data/mnesia'

config :kaguya,
  server: "irc.rizon.net",
  server_ip_type: :inet,
  port: 6697,
  bot_name: "Aru",
  channels: ["#vndis"],
  help_cmd: ".help",
  use_ssl: true,
  reconnect_interval: 5
