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
    match ".ping", :ping_handler, doc: "Responds with ping"
    match ".vn ~title", :vn_handler, async: true, doc: "Looks-up VN"
    match ".hook :cmd ~arg", :hook, async: true, doc: "Access hook DB. Allowed commands: get, add, del"
    match ".hook :cmd", :hook_help, async: true, nodoc: true
    #match ".hook add ~args", :hook_add, async: true
    #match ".hook get ~title", :hook_get, async: true
    #match ".hook del ~title", :hook_del, async: true
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

  #add <???>
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "add"}) do
    reply "#{nick}: usage: add -t <title> -c <code> [-k <kanji>] [-v <version>]"
  end

  def add_vn(options) do
    title = options[:title]
    case Db.Repo.get_vn(title) do
      nil ->
        code = options[:code]
        versions = case Keyword.has_key?(options, :version) do
          true -> %{options[:version] => code}
          false -> %{}
        end

        vn = Db.Hook.create_w_validation(title, title, Keyword.get(options, :kanji, nil), versions)

        case Db.Repo.insert(vn) do
          {:ok, _} -> "'#{title}': Has been added to DB."
          {:error, _} -> "'#{title}': Couldn't be added to DB."
        end

      _ -> "'#{title}': Already exists. Use update command to change it"
    end
  end

  @add_opts [switches: [title: :string, code: :string, kanji: :string, version: :string],
             aliases: [t: :title, c: :code, k: :kanji, v: :version]]
  @add_mandatory_opts [:title, :code]
  defh hook(%{user: %{nick: nick}}, %{"cmd" => "add", "arg" => arg}) do
    case OptionParser.parse(OptionParser.split(arg), @add_opts) do
      {args, [], []} ->
        if Enum.all?(@add_mandatory_opts, &(Keyword.has_key?(args, &1))) do
          reply add_vn(args)
        else
          reply "#{nick}: Insufficient number of arguments. See .help add"
        end
      _ -> reply "#{nick}: Bad arguments. See .help add"
    end
  end

  #update
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "update"}) do
    reply "#{nick}: usage: update -t <title> -c <code> [-k <kanji>] [-v <version>]"
  end

  def update_vn(options) do
    title = options[:title]
    case Db.Repo.get_vn(title) do
      nil -> "'#{title}': Doesn't exists. Use add command to create it."
      vn ->
        code = options[:code]
        versions = case Keyword.has_key?(options, :version) do
          true -> Map.put(vn.versions, options[:version], code)
          false -> vn.versions
        end

        vn = Db.Hook.changeset(vn, %{
          name: title,
          code: code,
          kanji: Keyword.get(options, :kanji, vn.kanji),
          versions: versions
        })

        case Db.Repo.update(vn) do
          {:ok, _} -> "'#{title}': Has been update."
          {:error, _} -> "'#{title}': Couldn't be update."
        end
    end
  end

  defh hook(%{user: %{nick: nick}}, %{"cmd" => "update", "arg" => arg}) do
    case OptionParser.parse(OptionParser.split(arg), @add_opts) do
      {args, [], []} ->
        if Enum.all?(@add_mandatory_opts, &(Keyword.has_key?(args, &1))) do
          reply update_vn(args)
        else
          reply "#{nick}: Insufficient number of arguments. See .help add"
        end
      _ -> reply "#{nick}: Bad arguments. See .help update"
    end
  end

  #Splits string into {title, version}
  #Version is specified using following format: `<title[#version]>`
  #In case missing version returns `{title, nil}`
  @spec split_title(String.t()) :: {String.t(), String.t()}
  defp split_title(title) do
    case String.split(title, "#", trim: true) do
      [title] -> {title, nil}
      parts ->
        {version, title_parts} = List.pop_at(parts, -1)
        {Enum.join(title_parts, ""), version}
    end
  end

  #get <title>
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "get"}) do
    reply "#{nick}: usage: get <Title[#version]>"
  end

  @spec get_hook(Ecto.Schema.t(), String.t()) :: String.t()
  defp get_hook(%{versions: versions} = _vn, nil) do
    Enum.map_join(versions, ", | ", fn({key, value}) -> "v#{key}:#{value}" end)
  end

  defp get_hook(%{versions: versions} = _vn, version) do
    case Map.get(versions, version, nil) do
      nil -> "'#{version}' is not present. Available versions: #{Enum.join(Map.keys(versions), ", ")}"
      code -> "#{code}"
    end
  end

  defp get_hook(vn, _version) do
    "#{vn.code}"
  end

  defh hook(%{user: %{nick: nick}}, %{"cmd" => "get", "arg" => title}) do
    {title, version} = split_title(title)
    case Db.Repo.get_vn(title) do
      nil -> reply "#{nick}: No hook for '#{title}' :("
      result -> reply "#{nick}: #{result.name} - #{get_hook(result, version)}"
    end
  end

  #del <title>
  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => "del"}) do
    reply "#{nick}: usage: del <Title[#version]>"
  end

  @spec del_title(Ecto.Schema.t(), String.t()) :: String.t()
  defp del_title(%{versions: _versions} = vn, nil) do
    case Db.Repo.delete(vn) do
      {:ok, _} -> "#{vn.name} is deleted"
      _ -> "#{vn.name} could not be deleted"
    end
  end

  defp del_title(%{versions: versions} = vn, version) do
    case Map.pop(versions, version, nil) do
      {nil, _} -> "#{version} is not present. Available versions: #{Enum.join(Map.keys(versions), ", ")}"
      {_, versions}  ->
        vn = Db.Hook.changeset(vn, %{
          name: vn.name,
          code: vn.code,
          kanji: vn.kanji,
          versions: versions
        })

        case Db.Repo.update(vn) do
          {:ok, _} -> "'#{vn.name}': Has been update."
          {:error, _} -> "'#{vn.name}': Couldn't be update."
        end
    end
  end

  defp del_title(vn, _version) do
    case Db.Repo.delete(vn) do
      {:ok, _} -> "#{vn.name} is deleted"
      _ -> "#{vn.name} could not be deleted"
    end
  end

  defh hook(%{user: %{nick: nick}}, %{"cmd" => "del", "arg" => title}) do
    {title, version} = split_title(title)
    case Db.Repo.get_vn(title) do
      nil -> reply "#{nick}: No hook for '#{title}' already"
      result -> reply "#{nick}: #{del_title(result, version)}"
    end
  end

  #bad hook cmd
  defh hook(%{user: %{nick: nick}}, %{"cmd" => cmd, "arg" => _}) do
    reply "#{nick}: bad command '#{cmd}'. Allowed commands: add, get and del"
  end

  defh hook_help(%{user: %{nick: nick}}, %{"cmd" => cmd}) do
    reply "#{nick}: bad command '#{cmd}'. Allowed commands: add, get and del"
  end

end
