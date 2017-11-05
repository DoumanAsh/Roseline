defmodule Roseline.Irc.Bot do
  @moduledoc """
  Bot module for Roseline
  """
  use GenServer
  require Logger

  defmodule Config do
    @moduledoc "Configuration module"
    defstruct server:  nil,
              port:    nil,
              ssl?:    false,
              pass:    "",
              nick:    nil,
              user:    nil,
              name:    nil,
              channel: nil,
              client:  nil


    #Inserts value into config if its key exists there
    #Returns provided Config.
    @spec insert_if({any(), any()}, %Config{}) :: %Config{}
    def insert_if({key, value}, config) do
      case Map.has_key?(config, key) do
        true  -> Map.put(config, key, value)
        false -> config
      end
    end

    @doc """
    Constructs Configuration from parameters.
    """
    @spec from_params(map()) :: %Config{}
    def from_params(params) do
      Enum.reduce(params, %Config{}, &insert_if/2)
    end

  end

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{:nick => nick} = params) do
    GenServer.start_link(__MODULE__, [Config.from_params(params)], name: String.to_atom(nick))
  end

  @spec init([%Config{}]) :: {:ok, any()}
  def init([config]) do
    {:ok, client} = ExIrc.start_link!()

    ExIrc.Client.add_handler(client, self())
    config = Map.put(config, :client, client)
    send(self(), :connect)

    {:ok, config}
  end

  def handle_info(:connect, config) do
    Logger.info fn -> 'Connecting to #{config.server}:#{config.port}...' end
    case config.ssl? do
      true -> ExIrc.Client.connect_ssl!(config.client, config.server, config.port)
      false -> ExIrc.Client.connect!(config.client, config.server, config.port)
    end

    {:noreply, config}
  end

  def handle_info({:connected, server, port}, config) do
    Logger.info "Connected to #{server}:#{port}. Logging as #{config.nick}"

    case ExIrc.Client.logon(config.client, config.pass, config.nick, config.user, config.name) do
      :ok -> nil
      {:error, reason} -> Logger.error fn -> 'Failed to logon. Reason: #{reason}' end
    end

    {:noreply, config}
  end

  def handle_info(:disconnected, config) do
    Logger.info fn -> "Disconnected from #{config.server}:#{config.port}. Reconnect..." end
    send(self(), :connect)
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.info fn -> "Logged in to #{config.server}:#{config.port}. Joining #{config.channel}..." end

    joins(config.client, config.channel)
    {:noreply, config}
  end

  def handle_info({:join, channel}, config) do
    joins(config.client, channel)
    {:noreply, config}
  end

  #We joined
  def handle_info({:joined, channel}, config) do
    Logger.debug fn -> "Joined #{channel}" end
    privmsg("みなさん、ごきげんよう", channel, config.client)
    {:noreply, config}
  end

  #Someone joins
  def handle_info({:joined, channel, %ExIrc.SenderInfo{:nick => nick}}, config) do
    Logger.debug fn -> "User '#{nick}' joins channel #{channel}" end
    {:noreply, config}
  end

  #We're kicked
  def handle_info({:kicked, %ExIrc.SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn fn -> "User '#{nick}' kicks us out of channel #{channel}" end
    #rejoin channel in 1 second
    Process.send_after(self(), {:join, channel}, 1000)
    {:noreply, config}
  end

  #Receives some message in channel
  def handle_info({:received, msg, %ExIrc.SenderInfo{:nick => nick}, channel}, config) do
    Logger.info fn -> "#{nick} from #{channel}: #{msg}" end
    Roseline.Irc.Bot.CommandTask.start(nick, msg, channel, config.client)
    {:noreply, config}
  end

  #Receives message directly
  def handle_info({:received, msg, %ExIrc.SenderInfo{:nick => nick}}, config) do
    Logger.info fn -> "#{nick}: #{msg}" end
    Roseline.Irc.Bot.CommandTask.start(nick, msg, nick, config.client)
    {:noreply, config}
  end

  #We're mentioned in someone's message
  def handle_info({:mentioned, _msg, %ExIrc.SenderInfo{:nick => nick}, channel}, config) do
    Logger.info fn -> "#{nick} mentions me on #{channel}" end
    {:noreply, config}
  end

  # Catch-all for messages you don't care about
  def handle_info(msg, config) do
    Logger.debug fn -> '#{inspect(msg)}' end
    {:noreply, config}
  end

  @spec terminate(any(), %Config{}) :: :ok
  def terminate(_, state) do
    ExIrc.Client.quit(state.client, "Farewell...")
    ExIrc.Client.stop!(state.client)
    :ok
  end

  @doc """
  Shortcut to send privmsg.
  """
  @spec privmsg(binary(), binary(), pid()) :: :ok | {:error, atom()}
  def privmsg(message, channel, client) do
    ExIrc.Client.msg(client, :privmsg, channel, message)
  end

  ## Internal utils
  #Joins specified channels
  @spec joins(pid(), list() | binary) :: nil
  defp joins(client, [head | tail]) do
    ExIrc.Client.join(client, head)
    joins(client, tail)
  end

  defp joins(_client, []) do
  end

  defp joins(client, channel) do
    ExIrc.Client.join(client, channel)
  end

end
