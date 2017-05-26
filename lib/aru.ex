defmodule Aru do
  @moduledoc """
  Aru bot.
  """
  require Logger
  use Kaguya.Module, "Aru"

  def module_init do
    EliVndb.Client.start_link
  end

  handle "PRIVMSG" do
    match ".ping", :ping_handler
    match ".vn ~title", :vn_handler, async: true
  end

  defh ping_handler(%{user: %{nick: nick}}) do
    reply "#{nick}: pong"
  end

  defh vn_handler(%{user: %{nick: nick}}, %{"title" => title}) do
    import EliVndb.Filters
    title = String.trim(title)
    case EliVndb.Client.get_vn(filters: ~f(title ~ "#{title}" or original ~ "#{title}")) do
      {:results, %{"items" => [item | _], "num" => 1}} -> reply "#{nick}: https://vndb.org/v#{item["id"]}"
      _ -> reply "#{nick}: https://vndb.org/v/all?sq=#{String.replace(title, " ", "+")}"
    end
  end

end
