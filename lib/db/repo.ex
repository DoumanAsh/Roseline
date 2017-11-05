defmodule Db.Repo do
  @moduledoc "DB Repo"
  use Ecto.Repo, otp_app: :roseline

  @spec add_hook(integer(), String.t(), String.t() | nil) :: atom()
  def add_hook(id, code, version) do
    case get_hook(id) do
      nil ->
        versions = case version do
          nil -> %{}
          _ -> %{version => code}
        end

        vn = Db.Hook.create_w_validation(id, code, versions)

        {result, _} = Db.Repo.insert(vn)

        result
      _ -> :already
    end
  end

  @spec update_hook(integer(), String.t(), String.t() | nil) :: atom()
  def update_hook(id, code, nil) do
    case get_hook(id) do
      nil -> :no_hook
      vn ->
        vn = Db.Hook.changeset(vn, %{code: code})

        {result, _} = Db.Repo.update(vn)

        result
    end
  end

  def update_hook(id, code, version) do
    case get_hook(id) do
      nil -> :no_hook
      vn ->
        versions = Map.put(vn.versions, version, code)
        vn = Db.Hook.changeset(vn, %{code: code, versions: versions})

        case Db.Repo.update(vn) do
          {:ok, _} -> :version_updated
          {result, _} -> result
        end
    end
  end

  @spec delete_hook(Ecto.Schema.t(), String.t() | nil) :: atom()
  def delete_hook(%{versions: _versions} = vn, nil) do
    {result, _} = Db.Repo.delete(vn)
    result
  end

  def delete_hook(%{versions: versions} = vn, version) do
    case Map.pop(versions, version, nil) do
      {nil, _} -> :bad_version
      {_, versions}  ->
        vn = Db.Hook.changeset(vn, %{code: vn.code, versions: versions})

        case Db.Repo.update(vn) do
          {:ok, _} -> :version_removed
          {result, _} -> result
        end
    end
  end

  def delete_hook(vn, _version) do
    {result, _} = Db.Repo.delete(vn)
    result
  end

  @spec get_hook(integer()) :: Ecto.Schema.t() | nil
  def get_hook(id) do
    Db.Repo.get(Db.Hook, id)
  end

  @spec get_all_hooks() :: [map()]
  def get_all_hooks() do
    require Ecto.Query
    Enum.map(Db.Repo.all(Ecto.Query.from p in Db.Hook, order_by: [asc: p.id]), &Map.take(&1, [:id, :code, :versions]))
  end

end
