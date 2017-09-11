defmodule Roseline.Irc.Bot.CommandTask do
  @moduledoc """
  Bot commands for IRC
  """
  use Task
  alias Roseline.Irc.Bot.Handlers, as: Handlers

  defmodule Job do
    @moduledoc "Command handler job"
    defstruct msg:  nil,
              nick: nil,
              from: nil,
              client: nil

    @spec new(binary(), binary(), binary(), pid()) :: %Job{}
    def new(nick, msg, from, client) do
      struct(Job, [
        nick: nick,
        msg: msg,
        from: from,
        client: client
      ])
    end

  end

  @doc """
  Starts handling IRC's message.

  Arguments:
  * `nick` - User that sent message.
  * `msg` - Message's content.
  * `from` - Chanell from which it has been sent. Can be the same as `nick`.
  * `client` - ExIrc's client.
  """
  @spec start(binary(), binary(), binary(), pid()) :: {:ok, pid()}
  def start(nick, msg, from, client) do
    Task.start(__MODULE__, :run, [Job.new(nick, String.trim(msg), from, client)])
  end

  @spec run(%Job{}) :: :ok | {:error, atom()}
  def run(job) do
    reply(job, Handlers.handle(job.msg))
  end

  @spec reply(%Job{}, binary | list(binary) |  nil) :: :ok | {:error, atom()}
  defp reply(_job, nil), do: :ok
  defp reply(_job, []), do: :ok
  defp reply(job, [head | rest]) do
    reply(job, head)
    reply(job, rest)
  end
  defp reply(job, msg) do
    if job.nick == job.from do
      ExIrc.Client.msg(job.client, :privmsg, job.from, msg)
    else
      ExIrc.Client.msg(job.client, :privmsg, job.from, "#{job.nick}: #{msg}")
    end
  end

end
