defmodule Rill.Shore.Callback do
  use Rill.T

  @callback init_state(id :: any) :: state()
  @callback pre_handle(envir :: envir(), msg :: msg(), state :: state()) ::
              {:ok, state()}
              | {:end, {:noreply, state()}}
              | {:end, {:reply, any(), state()}}
  @callback terminate(state :: state()) :: any()
end

defmodule Rill.Shore.Tcp.Callback do
  use Rill.T

  @callback decode_binary(data :: binary()) :: {:ok, flow(), any()} | any()
end

defmodule Rill.Shore do
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Rill.Shore.Callback
      import Rill.Flow
      alias Rill.Flow.Msg
      use Rill.Alias
    end
  end
end

defmodule Rill.Shore.Tcp do
  defmacro __using__(_) do
    quote location: :keep do
      use Rill.Shore
      @behaviour Rill.Shore.Tcp.Callback
    end
  end
end
