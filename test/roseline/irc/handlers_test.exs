defmodule Roseline.Irc.Bot.Handlers.Test do
  use ExUnit.Case, async: true
  alias Roseline.Irc.Bot.Handlers, as: Handlers

  test "Ping" do
    assert(Handlers.handle(".ping") == "pong")
  end

  test "Get VN by title" do
    assert(Handlers.handle(".vn Amayui") == "https://vndb.org/v20418")
    assert(Handlers.handle("v20418") == ["v20418 Amayui Castle Meister - https://vndb.org/v20418"])
  end

  test "Work with hook" do
    assert(Handlers.handle(".hook add -t Amayui#1.01 -c fisrt") == "'Amayui': Has been added to DB.")
    assert(Handlers.handle(".hook get Amayui") == "Amayui - v1.01:fisrt")
    assert(Handlers.handle(".hook add -t Amayui#1.02 -c second") == "'Amayui': Already exists. Use update command to change it.")
    assert(Handlers.handle(".hook update -t Amayui#1.02 -c second") == "'Amayui': Updated with version 1.02.")
    assert(Handlers.handle(".hook get Amayui") == "Amayui - v1.01:fisrt | v1.02:second")
    assert(Handlers.handle(".hook get Amayui#1.01") == "Amayui - fisrt")
    assert(Handlers.handle(".hook get Amayui#1.02") == "Amayui - second")
    assert(Handlers.handle(".hook del Amayui#1.01") == "1.01 is removed for 'Amayui'.")
    assert(Handlers.handle(".hook get Amayui#1.01") == "Amayui - '1.01' is not present. Available versions: 1.02")
    assert(Handlers.handle(".hook get Amayui#1.02") == "Amayui - second")
    assert(Handlers.handle(".hook get Amayui") == "Amayui - v1.02:second")
    assert(Handlers.handle(".hook del Amayui#1.02") == "1.02 is removed for 'Amayui'.")
    assert(Handlers.handle(".hook get Amayui#1.02") == "Amayui - '1.02' is not present. Available versions: ")
    assert(Handlers.handle(".hook get Amayui") == "Amayui - second")
    assert(Handlers.handle(".hook del Amayui") == "'Amayui' is removed.")
    assert(Handlers.handle(".hook get Amayui") == "No hook for 'Amayui' :(")
  end

end
