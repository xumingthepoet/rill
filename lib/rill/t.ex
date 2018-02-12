defmodule Rill.T do
  defmacro __using__(_) do
    quote do
      @type method :: :cast | :call | :timer
      @type internal_module :: atom
      @type msg :: any
      @type state :: map
      @type flow :: module
      @type envir :: %{
              m: method :: method(),
              sm: sender_module :: internal_module(),
              rm: receiver_module :: internal_module(),
              sp: sender_pid :: pid(),
              rp: receiver_pid :: pid(),
              f: flow :: flow(),
              d: delay :: integer()
            }
    end
  end
end
