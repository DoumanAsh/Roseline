defmodule Db.Repo do
  @moduledoc "DB Repo"
  use Ecto.Repo, otp_app: :aru

  @spec get_vn(String.t()) :: Ecto.Schema.t() | nil
  def get_vn(title) do
    import Ecto.Query, only: [from: 2]

    Db.Repo.one(
      from h in Db.Hook,
      where: h.name == ^title,
      limit: 1,
      select: h
    )
  end

end
