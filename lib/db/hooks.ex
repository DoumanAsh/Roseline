defmodule Db.Hook do
  @moduledoc "Hook schema"
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "hooks" do
    field :code, :string
    field :versions, {:map, :string}
  end

  def changeset(hook, params \\ %{}) do
    import Ecto.Changeset

    hook
    |> cast(params, [:code, :versions])
    |> validate_required([:id, :code])
  end

  def create_w_validation(id, code, versions \\ %{}) do
    changeset(%Db.Hook{id: id}, %{code: code, versions: versions})
  end
end
