defmodule Aru.Vndis do
  @moduledoc """
  Bot module for #vndis
  """
  require Logger
  use Kaguya.Module, "Aru"

  @vndb_vn_id ~r/(^|\s)v([0-9]+)/

  handle "PRIVMSG" do
    match ".ping", :ping_handler, doc: "Responds with ping"
    match ".cache", :cache_handler, doc: "Responds with size of bot's cache"
    match ".vn ~title", :vn_handler, async: true, doc: "Looks-up VN"
    match ".hook :cmd ~arg", :hook, async: true, doc: "Access hook DB. Allowed commands: get, add, update, del"
    match ".hook :cmd", :hook_help, async: true, nodoc: true
    match_re ~r/.h([0-9]+)$/, :h, async: true, doc: "Shortcut to get hook by VNDB ID"
    match_all :vndb_high_handler, async: true
  end

  defh vndb_high_handler(%{trailing: msg}) do
    import EliVndb.Filters
    result = case String.starts_with?(msg, ".") do
      false -> Regex.scan(@vndb_vn_id, msg, capture: :all_but_first)
      true -> []
    end

    Enum.each result, fn capture ->
      id = case capture do
        [_, right] -> right
        [left] -> left
      end

      case Aru.Vndb.get_vn(filters: ~f(id = #{id})) do
        {:results, %{"items" => [item | _], "num" => 1}} -> reply "v#{id} #{item["title"]} - https://vndb.org/v#{item["id"]}"
        _ -> :noop
      end
    end
  end

  defh cache_handler(%{user: %{nick: nick}}) do
    reply "#{nick}: cache size='#{Aru.Vndb.cache_size()}'"
  end

  defh ping_handler(%{user: %{nick: nick}}) do
    reply "#{nick}: pong"
  end

  defp try_yourself(title, type \\ "v") do
    "Try yourself -> https://vndb.org/#{type}/all?sq=#{String.replace(title, " ", "+")}"
  end

  defh vn_handler(%{user: %{nick: nick}}, %{"title" => title}) do
    import EliVndb.Filters
    title = String.trim(title)
    case Aru.Vndb.get_vn(filters: ~f(title ~ "#{title}" or original ~ "#{title}")) do
      {:results, %{"items" => [item | _], "num" => 1}} -> reply "#{nick}: https://vndb.org/v#{item["id"]}"
      {:results, %{"num" => 0}} -> reply "#{nick}: Couldn't find anything. #{try_yourself(title)}"
      {:results, %{"num" => num}} -> reply "#{nick}: There are too many hits='#{num}'. #{try_yourself(title)}"
      result ->
        Logger.error fn -> 'Unexpected result "#{inspect(result)}"' end
        reply "#{nick}: Error processing your request. #{try_yourself(title)}"
    end
  end

  #Splits string into {title, version}
  #Version is specified using following format: `<title[#version]>`
  #In case missing version returns `{title, nil}`
  @spec split_title(String.t()) :: {String.t(), String.t() | nil}
  defp split_title(title) do
    case String.split(title, "#", trim: true) do
      [title] -> {title, nil}
      parts ->
        {version, title_parts} = List.pop_at(parts, -1)
        {Enum.join(title_parts, ""), version}
    end
  end

  @spec title_to_vndb_id(String.t()) :: {:ok, integer()} | {:error, String.t()}
  defp title_to_vndb_id(title) do
    import EliVndb.Filters
    case Regex.run(@vndb_vn_id, title, capture: :all_but_first) do
      [_, id] -> {:ok, String.to_integer(id)}
      nil ->
        case Aru.Vndb.get_vn(filters: ~f(title ~ "#{title}" or original ~ "#{title}")) do
          {:results, %{"items" => [item | _], "num" => 1}} -> {:ok, item["id"]}
          {:results, %{"num" => 0}} -> {:error, "'#{title}': No such VN..."}
          {:results, %{"num" => num}} -> {:error, "'#{title}': Too many hits='#{num}'. #{try_yourself(title)}"}
          result ->
            Logger.error fn -> 'Unexpected result "#{inspect(result)}"' end
            "Error processing your request. #{try_yourself(title)}"
        end
    end
  end

  #add hook
  @add_opts [switches: [title: :string, code: :string],
             aliases: [t: :title, c: :code]]
  @add_mandatory_opts [:title, :code]

  @spec add_hook(Keyword.t()) :: String.t()
  defp add_hook(args) do
    {title, version} = split_title(args[:title])
    code = args[:code]

    case title_to_vndb_id(title) do
      {:ok, id} ->
        case Db.Repo.add_hook(id, code, version) do
          :ok -> "'#{title}': Has been added to DB."
          :already -> "'#{title}': Already exists. Use update command to change it."
          :error -> "'#{title}': Couldn't be added to DB."
        end
      {:error, msg} -> msg
    end
  end

  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "add"}) do
    reply "#{nick}: usage: add -t <title[#version]> -c <code>"
  end

  defh hook(%{user: %{nick: nick}}, %{"cmd" => "add", "arg" => arg}) do
    case OptionParser.parse(OptionParser.split(arg), @add_opts) do
      {args, [], []} ->
        case Enum.all?(@add_mandatory_opts, &(Keyword.has_key?(args, &1))) do
          true -> reply "#{nick}: #{add_hook(args)}"
          false -> reply "#{nick}: Insufficient number of arguments. See .help add"
        end
      _ -> reply "#{nick}: Bad arguments. See .help add"
    end
  end

  #update
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "update"}) do
    reply "#{nick}: usage: update -t <title[#version]> -c <code>"
  end

  @spec update_hook(Keyword.t()) :: String.t()
  defp update_hook(args) do
    {title, version} = split_title(args[:title])
    code = args[:code]

    case title_to_vndb_id(title) do
      {:ok, id} ->
        case Db.Repo.update_hook(id, code, version) do
          :ok -> "'#{title}': Has been updated in DB."
          :version_updated -> "'#{title}': Updated with version #{version}."
          :no_hook -> "'#{title}': Doesn't exist. Use 'add' command to create it"
          :error -> "'#{title}': Couldn't be added to DB."
        end
      {:error, msg} -> msg
    end
  end


  defh hook(%{user: %{nick: nick}}, %{"cmd" => "update", "arg" => arg}) do
    case OptionParser.parse(OptionParser.split(arg), @add_opts) do
      {args, [], []} ->
        case Enum.all?(@add_mandatory_opts, &(Keyword.has_key?(args, &1))) do
          true -> reply "#{nick}: #{update_hook(args)}"
          false -> reply "#{nick}: Insufficient number of arguments. See .help add"
        end
      _ -> reply "#{nick}: Bad arguments. See .help update"
    end
  end

  #get <title>
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "get"}) do
    reply "#{nick}: usage: get <Title[#version]>"
  end

  @spec get_hook(Db.Hook.t(), String.t() | nil) :: String.t()
  defp get_hook(%{versions: versions} = vn, nil) do
    case Map.keys(versions) do
      [] -> vn.code
      _ -> Enum.map_join(versions, " | ", fn({key, value}) -> "v#{key}:#{value}" end)
    end
  end

  defp get_hook(%{versions: versions} = _vn, version) do
    case Map.get(versions, version, nil) do
      nil -> "'#{version}' is not present. Available versions: #{Enum.join(Map.keys(versions), ", ")}"
      code -> "#{code}"
    end
  end

  defh hook(%{user: %{nick: nick}}, %{"cmd" => "get", "arg" => title}) do
    {title, version} = split_title(title)
    case title_to_vndb_id(title) do
      {:ok, id} ->
        case Db.Repo.get_hook(id) do
          nil -> reply "#{nick}: No hook for '#{title}' :("
          result -> reply "#{nick}: #{title} - #{get_hook(result, version)}"
        end
      {:error, msg} -> reply msg
    end
  end

  #del <title>
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "del"}) do
    reply "#{nick}: usage: del <Title[#version]>"
  end

  defh hook(%{user: %{nick: nick}}, %{"cmd" => "del", "arg" => title}) do
    {title, version} = split_title(title)
    case title_to_vndb_id(title) do
      {:ok, id} ->
        case Db.Repo.get_hook(id) do
          nil -> reply "#{nick}: No hook for '#{title}' already."
          result ->
            case Db.Repo.delete_hook(result, version) do
              :ok -> reply "#{nick}: '#{title}' is removed."
              :version_removed -> reply "#{nick}: #{version} is removed for '#{title}'."
              :bad_version -> reply "#{nick}: #{version} is not present for '#{title}'."
              :error -> reply "#{nick}: Failed to remove '#{title}'."
            end
        end
      {:error, msg} -> reply msg
    end
  end

  #bad hook cmd
  defh hook(%{user: %{nick: nick}}, %{"cmd" => cmd, "arg" => _}) do
    reply "#{nick}: bad command '#{cmd}'. Allowed commands: add, get, update and del"
  end

  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => cmd}) do
    reply "#{nick}: bad command '#{cmd}'. Allowed commands: add, get, update and del"
  end

  defh h(%{trailing: <<_::binary-size(2), id::binary>>, user: %{nick: nick}}) do
    case Db.Repo.get_hook(id) do
      nil -> reply "#{nick}: No hook for 'v#{id}' :("
      result -> reply "#{nick}: v#{id} - #{get_hook(result, nil)}"
    end
  end
end
