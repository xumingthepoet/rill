defmodule Template.Module do
  use GenServer
  require Logger

  @shore_name Template.Shore
  @supervisor_name Module.concat(__MODULE__, Supervisor)

  @spec create(data :: any) :: {:ok, pid} | {:error, any}
  def create(data) do
    @supervisor_name.start_child(data)
  end

  def start_link(data, _opts \\ []) do
    GenServer.start_link(__MODULE__, data, [])
  end

  def init(data) do
    {:ok, data, 0}
  end

  def handle_cast(%Rill.Flow.Msg{} = msg, state) do
    opts = %{m: :cast, rm: __MODULE__, rp: self()}
    Rill.handle_flow(@shore_name, opts, msg, state)
  end

  def handle_cast(msg, state) do
    Logger.warn(fn ->
      "unknown msg: #{inspect(msg)} is casted to module: #{inspect(__MODULE__)}"
    end)

    {:noreply, state}
  end

  def handle_call(%Rill.Flow.Msg{} = msg, _from, state) do
    opts = %{m: :call, rm: __MODULE__, rp: self()}
    Rill.handle_flow(@shore_name, opts, msg, state)
  end

  def handle_call(msg, _from, state) do
    Logger.warn(fn ->
      "unknown msg: #{inspect(msg)} is called to module: #{inspect(__MODULE__)}"
    end)

    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    state = @shore_name.init_state(state)
    {:noreply, state}
  end

  def handle_info({:timer, %Rill.Flow.Msg{} = msg}, state) do
    opts = %{m: :timer, rm: __MODULE__, rp: self()}
    Rill.handle_flow(@shore_name, opts, msg, state)
  end

  def handle_info(msg, _from, state) do
    Logger.warn(fn ->
      "unknown msg: #{inspect(msg)} is sent to module: #{inspect(__MODULE__)}"
    end)

    {:noreply, state}
  end

  def terminate(reason, state) do
    if reason != :normal do
      Logger.warn(fn ->
        "module: #{inspect(__MODULE__)} is terminated by unnormal reason: #{inspect(reason)}"
      end)
    end

    @shore_name.terminate(state)
    :ok
  end

  defmodule Supervisor do
    use Elixir.Supervisor

    def start_link(module) do
      Elixir.Supervisor.start_link(__MODULE__, module, name: __MODULE__)
    end

    def start_child(data) do
      Elixir.Supervisor.start_child(__MODULE__, [data])
    end

    def init(module) do
      children = [worker(module, [], restart: :temporary)]
      supervise(children, strategy: :simple_one_for_one)
    end
  end
end
