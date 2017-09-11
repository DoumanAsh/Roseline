defmodule Roseline.Irc.Bot.Handlers do
  @moduledoc """
  Handlers for IRC commands.
  """

  @vndb_vn_id ~r/(^|\s)v([0-9]+)/

  # Handles Bot commands
  @spec handle_cmd(binary()) :: nil | binary()
  defp handle_cmd("help"), do: "Available commands: .ping, .pong, .cache, .vn, .hook"
  defp handle_cmd("ping"), do: "pong"
  defp handle_cmd("cache"), do: "cache size='#{Roseline.Vndb.cache_size()}'"
  defp handle_cmd("vn" <> " " <> title) do
    title = String.trim(title)

    case Roseline.Vndb.look_up_vn(title) do
      {:ok, item} -> "https://vndb.org/v#{item["id"]}"
      :not_found -> "Couldn't find anything. #{try_yourself(title)}"
      {:too_many, num} -> "There are too many hits='#{num}'. #{try_yourself(title)}"
      :error -> "Error processing your request. #{try_yourself(title)}"
    end
  end
  defp handle_cmd("vn"), do: "Which VN...?"

  defp handle_cmd("hook" <> " " <> rest) do
    handle_cmd_hook(rest)
  end
  defp handle_cmd("hook") do
    handle_cmd_hook()
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
    case Regex.run(@vndb_vn_id, title, capture: :all_but_first) do
      [_, id] -> {:ok, String.to_integer(id)}
      nil ->
        case Roseline.Vndb.look_up_vn(title) do
          {:ok, item} -> {:ok, item["id"]}
          :not_found -> {:error, "'#{title}': No such VN..."}
          {:too_many, num} -> {:error, "'#{title}': Too many hits='#{num}'. #{try_yourself(title)}"}
          :error -> "Unexpected error while processing your request. #{try_yourself(title)}"
        end
    end
  end

  #Retrieves hook from DB.
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

  #update hook
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

  @spec handle_cmd_hook(binary()) :: nil | binary()
  defp handle_cmd_hook("add" <> " " <> args) do
    case OptionParser.parse(OptionParser.split(args), @add_opts) do
      {args, [], []} ->
        case Enum.all?(@add_mandatory_opts, &(Keyword.has_key?(args, &1))) do
          true -> add_hook(args)
          false -> "Insufficient number of arguments. See .hook add"
        end
      _ -> "Bad arguments. See .help add"
    end
  end
  defp handle_cmd_hook("update" <> " " <> args) do
    case OptionParser.parse(OptionParser.split(args), @add_opts) do
      {args, [], []} ->
        case Enum.all?(@add_mandatory_opts, &(Keyword.has_key?(args, &1))) do
          true -> update_hook(args)
          false -> "Insufficient number of arguments. See .help add"
        end
      _ -> "Bad arguments. See .hook update"
    end
  end
  defp handle_cmd_hook("get" <> " " <> args) do
    {title, version} = split_title(args)
    case title_to_vndb_id(title) do
      {:ok, id} ->
        case Db.Repo.get_hook(id) do
          nil -> "No hook for '#{title}' :("
          result -> "#{title} - #{get_hook(result, version)}"
        end
      {:error, msg} -> msg
    end
  end
  defp handle_cmd_hook("del" <> " " <> args) do
    {title, version} = split_title(args)
    case title_to_vndb_id(title) do
      {:ok, id} ->
        case Db.Repo.get_hook(id) do
          nil -> "No hook for '#{title}' already."
          result ->
            case Db.Repo.delete_hook(result, version) do
              :ok -> "'#{title}' is removed."
              :version_removed -> "#{version} is removed for '#{title}'."
              :bad_version -> "#{version} is not present for '#{title}'."
              :error -> "Failed to remove '#{title}'."
            end
        end
      {:error, msg} -> msg
    end
  end

  defp handle_cmd_hook("add"), do: "Usage: add -t <title#version> -c <code>"
  defp handle_cmd_hook("update"), do: "Usage: update -t <title#version> -c <code>"
  defp handle_cmd_hook("get"), do: "Usage: get <title#version> <code>"
  defp handle_cmd_hook("del"), do: "Usage: del <title#version> <code>"
  defp handle_cmd_hook(cmd), do: "Bad hook sub command '#{cmd}'. #{handle_cmd_hook()}"
  defp handle_cmd_hook(), do: ".hook commands: add, update, get, del"

  @doc "Parses command and return result, if necessary"
  @spec handle(binary()) :: nil | binary() | list(binary)
  def handle("." <> cmd), do: handle_cmd(cmd)
  @doc "Handles normal messages."
  def handle(msg) do
    find_vns(msg)
  end

  defp get_vn_by_id(capture) do
    import EliVndb.Filters
    id = case capture do
      [_, right] -> right
      [left] -> left
    end

    case Roseline.Vndb.get_vn(filters: ~f(id = #{id})) do
      {:results, %{"items" => [item | _], "num" => 1}} -> "v#{id} #{item["title"]} - https://vndb.org/v#{item["id"]}"
      _ -> :nil
    end
  end

  def find_vns(msg) do
    Regex.scan(@vndb_vn_id, msg, capture: :all_but_first)
    |> Enum.map(&get_vn_by_id/1)
    |> Enum.reject(&is_nil/1)
  end

  ###############
  #Internal utils
  ###############
  defp try_yourself(title, type \\ "v") do
    "Try yourself -> https://vndb.org/#{type}/all?sq=#{String.replace(title, " ", "+")}"
  end

end
