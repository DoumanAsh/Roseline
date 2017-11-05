defmodule Roseline.Irc.Bot.CommandTask do
  @moduledoc """
  Bot commands for IRC
  """
  use Task, restart: :transient
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

  defmodule Watcher do
    use GenServer, restart: :permanent

    @spec start_link() :: GenServer.on_start()
    def start_link() do
      {:ok, supervisor} = Task.Supervisor.start_link()
      GenServer.start_link(__MODULE__, [supervisor], name: __MODULE__)
    end

    @spec init([pid]) :: {:ok, any()}
    def init([supervisor]) do
      {:ok, supervisor}
    end

    @spec start(%Job{}) :: term()
    def start(job) do
      GenServer.call(__MODULE__, {:start, job})
    end

    def handle_call({:start, job}, _from, supervisor) do
      {:ok, pid} = Task.Supervisor.start_child(supervisor, Roseline.Irc.Bot.CommandTask, :run, [job])
      Process.monitor(pid)
      {:reply, :noop, supervisor}
    end

    #Ignore normal reasons
    def handle_info({:DOWN, _ref, :process, _object, :normal}, supervisor) do
      {:noreply, supervisor}
    end

    def handle_info({:DOWN, _ref, :process, object, reason}, supervisor) do
      require Logger

      Logger.warn fn -> 'Abnormal exit of task #{object}. Reason: #{reason}' end
      EliVndb.Client.stop()

      {:noreply, supervisor}
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
    Watcher.start(Job.new(nick, String.trim(msg), from, client))
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
      Roseline.Irc.Bot.privmsg(msg, job.from, job.client)
    else
      Roseline.Irc.Bot.privmsg("#{job.nick}: #{msg}", job.from, job.client)
    end
  end

end
