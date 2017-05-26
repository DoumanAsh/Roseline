# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :kaguya,
  server: "irc.rizon.net",
  server_ip_type: :inet,
  port: 6697,
  bot_name: "Aru",
  channels: ["#vndis"],
  help_cmd: ".help",
  use_ssl: true,
  reconnect_interval: 5
