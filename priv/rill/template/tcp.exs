defmodule Template.Module do
  use GenServer
  require Logger

  @behaviour :ranch_protocol

  @shore_name Template.Shore

  def start_link(ref, socket, transport, opts) do
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, _transport = :ranch_tcp, _opts = []) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)

    :ok =
      :ranch_tcp.setopts(socket, [
        :binary,
        {:packet, Application.get_env(:rill, :tcp_packet, 2)},
        {:packet_size, Application.get_env(:rill, :tcp_packet_size, 65535)},
        {:active, :once}
      ])

    Process.put(:socket, socket)
    state = @shore_name.init_state(nil)
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  # in case of behaviour warning
  def init(_) do
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(%Rill.Flow.Msg{} = msg, state) do
    handle_player(msg, state)
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, state) do
    :ranch_tcp.setopts(socket, [{:active, :once}])

    case @shore_name.decode_binary(data) do
      {:ok, flow, content} ->
        opts = %{m: :cast, rm: __MODULE__, rp: self()}
        msg = Rill.Flow.build_msg(content, flow)
        Rill.handle_flow(@shore_name, opts, msg, state)

      e ->
        Logger.warn(fn ->
          "decoding data failed, reason: #{inspect(e)}, data: #{inspect(data)}."
        end)

        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, _reason}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:timer, %Rill.Flow.Msg{} = msg}, state) do
    opts = %{m: :timer, rm: __MODULE__, rp: self()}
    Rill.handle_flow(@shore_name, opts, msg, state)
  end

  def handle_info(_request, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    socket = Process.get(:socket)

    if socket do
      try do
        :ranch_tcp.close(socket)
      rescue
        _ -> nil
      end
    end

    @shore_name.terminate(state)
    :ok
  end

  def handle_player(%Rill.Flow.Msg{} = msg, state) do
    opts = %{m: :cast, rm: __MODULE__, rp: self()}
    Rill.handle_flow(@shore_name, opts, msg, state)
  end

  def binary_to_client(binary) do
    socket = Process.get(:socket)

    if socket do
      :ranch_tcp.send(socket, binary)
    end
  end
end
