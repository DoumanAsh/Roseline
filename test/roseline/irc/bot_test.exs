defmodule Roseline.Irc.Bot.Test do
  use ExUnit.Case, async: true

  test "Create config" do
    config = %{:server => "irc.rizon.net", :port => 6697,
               :nick => "Roseline-test", :user => "Roseline-test", :name => "Roseline",
               :channel => "#vndis", :ssl? => true}
    result = Roseline.Irc.Bot.Config.from_params(config)
    assert(result.server == config.server)
    assert(result.port == config.port)
    assert(result.nick == config.nick)
    assert(result.user == config.user)
    assert(result.name == config.name)
    assert(result.channel == config.channel)
    assert(result.ssl? == config.ssl?)
  end

  test "Create config with extra field" do
    bare_config = Roseline.Irc.Bot.Config.from_params(%{})
    config = %{:server => "irc.rizon.net", :extra => true}
    result = Roseline.Irc.Bot.Config.from_params(config)

    assert(Map.keys(result) == Map.keys(bare_config))
  end
end
