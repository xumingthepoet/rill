defmodule Rill.Flow.Msg do
  use Rill.T

  defstruct flow: nil,
            content: nil,
            sender_module: nil,
            sender_pid: nil,
            delay: 0

  @type t :: %__MODULE__{
          flow: flow,
          content: any,
          sender_module: internal_module,
          sender_pid: pid,
          delay: integer
        }
end

defmodule Rill.Flow.Callback do
  use Rill.T

  @callback handle(envir :: envir(), msg :: msg(), state :: state()) ::
              :ok
              | {:noreply, state()}
              | {:reply, any(), state()}
              | {:stop, :normal, state()}
end

defmodule Rill.Flow do
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Rill.Flow.Callback
      import Rill.Flow
      alias Rill.Flow.Msg
      use Rill.Alias

      def call!(pid, msg) do
        Rill.Flow.call!(pid, msg, __MODULE__)
      end

      def cast(pid, msg) do
        Rill.Flow.cast(pid, msg, __MODULE__)
      end

      def set_timer(msg, delay) do
        Rill.Flow.set_timer(msg, delay, __MODULE__)
      end

      def set_timer(msg, delay, opts) when is_list(opts) do
        Rill.Flow.set_timer(msg, delay, __MODULE__, opts)
      end

      def cancel_timer(id) do
        Rill.Flow.cancel_timer(id, __MODULE__)
      end

      def cancel_timer(id, timer_filter) when is_function(timer_filter, 1) do
        Rill.Flow.cancel_timer(id, timer_filter, __MODULE__)
      end
    end
  end

  def call!(pid, msg, to_flow) do
    GenServer.call(pid, build_msg(msg, to_flow))
  end

  def cast(pid, msg, to_flow) do
    GenServer.cast(pid, build_msg(msg, to_flow))
  end

  def set_timer(msg, delay, to_flow) do
    set_timer(msg, delay, to_flow, id: msg, msg_filter: &(&1 == msg))
  end

  def set_timer(msg, delay, to_flow, opts) when is_list(opts) do
    id = Keyword.get(opts, :id, msg)
    msg_filter = Keyword.get(opts, :msg_filter, &(&1 == msg))
    cancel_timer(id, msg_filter, to_flow)
    timer = :erlang.send_after(delay, self(), {:timer, build_msg(msg, to_flow, delay: delay)})
    timers = Process.get(:timer, %{})
    timers = Map.put(timers, id, timer)
    Process.put(:timer, timers)
    timer
  end

  def cancel_timer(id, to_flow) do
    cancel_timer(id, &(&1 == id), to_flow)
  end

  def cancel_timer(id, msg_filter, to_flow) when is_function(msg_filter, 1) do
    timers = Process.get(:timer, %{})
    timer = Map.get(timers, id, nil)
    timers = Map.delete(timers, id)
    Process.put(:timer, timers)

    if timer do
      r = :erlang.cancel_timer(timer)
      clear_timer(msg_filter, to_flow)
      r
    else
      false
    end
  end

  defp clear_timer(msg_filter, to_flow) when is_function(msg_filter, 1) do
    receive do
      {:timer, %Rill.Flow.Msg{flow: ^to_flow, content: c}} = msg ->
        if msg_filter.(c) != true do
          send(self(), msg)
        end
    after
      0 -> nil
    end
  end

  def async_task(job) when is_function(job, 0) do
    try do
      spawn(job)
      true
    rescue
      _ ->
        false
    end
  end

  def build_msg(content, flow, opts \\ [delay: 0]) do
    %Rill.Flow.Msg{
      flow: flow,
      content: content,
      sender_module: get_process_module(),
      sender_pid: self(),
      delay: Keyword.get(opts, :delay, 0)
    }
  end

  defp get_process_module() do
    case Process.get(:"$initial_call") do
      t when is_tuple(t) -> elem(t, 0)
      _ -> nil
    end
  end

  def switch(flow, opts, msg, state) do
    opts = Enum.into([f: flow], opts)
    flow.handle(opts, msg, state)
  end
end
