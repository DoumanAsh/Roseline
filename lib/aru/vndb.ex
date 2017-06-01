defmodule Aru.Vndb do
  @moduledoc """
  VNDB Client wrapper.
  """

  @doc """
  Wraps EliVndb.Client.get_vn through Cachex layer.
  """
  @spec get_vn(EliVndb.Client.get_options()) :: term()
  def get_vn(options) do
    {_, result} = Cachex.get(Aru.cache_name, Keyword.put(options, :type, "vn"))
    result
  end

  @doc "Gets current size of cache"
  @spec cache_size() :: integer() | atom()
  def cache_size() do
    {_, result} = Cachex.size(Aru.cache_name)
    result
  end

end
