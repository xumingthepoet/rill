defmodule Rill.Supervisor do
  use Supervisor

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  def init(options) do
    app = Keyword.get(options, :app)
    structure = Keyword.get(options, :structure, %{servers: []})

    {[{tcp, _}], servers} =
      structure.servers
      |> Enum.split_with(fn {_, template: t} -> t == :tcp end)

    children =
      for {server, _} <- servers do
        server_name = Module.concat(app, server)
        supervisor_name = Module.concat(server_name, Supervisor)
        supervisor(supervisor_name, [server_name], restart: :permanent)
      end

    child_tcp_opts = [{:port, Keyword.get(options, :tcp_port)}, {:max_connections, 1_000_000}]

    child_tcp =
      :ranch.child_spec(:rill_tcp, 100, :ranch_tcp, child_tcp_opts, Module.concat(app, tcp), [])

    children = children ++ [child_tcp]

    supervise(children, strategy: :one_for_one)
  end
end
