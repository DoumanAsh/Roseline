defmodule Roseline.Vndb do
  @moduledoc """
  VNDB Client wrapper.
  """
  require Logger

  @doc """
  Wraps EliVndb.Client.get_vn through Cachex layer.
  """
  @spec get_vn(EliVndb.Client.get_options()) :: term()
  def get_vn(options) do
    {_, result} = Cachex.get(Roseline.cache_name, Keyword.put(options, :type, "vn"))
    result
  end

  @doc """
  Looks for VN by its title
  """
  @spec look_up_vn(binary()) :: atom() | {atom(), any()}
  def look_up_vn(title) do
    import EliVndb.Filters
    case Roseline.Vndb.get_vn(filters: ~f(title ~ "#{title}" or original ~ "#{title}")) do
      {:results, %{"items" => [item | _], "num" => 1}} -> {:ok, item}
      {:results, %{"num" => 0}} -> :not_found
      {:results, %{"num" => num}} -> {:too_many, num}
      result ->
        Logger.error fn -> 'Unexpected result "#{inspect(result)}"' end
        :error
    end
  end

  @doc "Gets current size of cache"
  @spec cache_size() :: integer() | atom()
  def cache_size() do
    {_, result} = Cachex.size(Roseline.cache_name)
    result
  end

end
