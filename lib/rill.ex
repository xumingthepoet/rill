defmodule Rill do
  @moduledoc """
    The basic usage of Rill module is as follows:
      defmodule Game do
        use Rill, servers: [{TcpModule, template: :tcp},
                            {PlayerLikeModule, template: :player},
                            {RoomLikeModule, template: :room},
                            {LeaderboardLikeModule, template: :leaderboard}]
      end

    `:tcp` template is a typical `:ranch_protocol` implement for `:cowboy` to use

    The `:player` template is a `:gen_server` with strategy `:simple_one_for_one`,
    It is started `globally` with an `id`:
      pid = PlayerLikeModule.Supervisor.start_child(data, id: id)
    and it can be located by:
      name = PlayerLikeModule.global_name(id)
      Rill.find_pid(name)

    The `:room` template is also a `:gen_server `with strategy `:simple_one_for_one`,
    but it is started `locally` as follows:
      pid = RoomLikeModule.Supervisor.start_child(data)
    So it is impossible to targeted it globally.

    The `:leaderboard` template is a :gen_server with strategy `:one_for_one`.
    It is also `:permanent`, and started at the very beginning. 
    No way to targeted it globally, but in a local condition
    you can find it as follows:
      pid = Process.whereis(LeaderboardLikeModule)

  """
  defmacro __using__(servers: servers) do
    app = __CALLER__.module

    quote location: :keep, bind_quoted: [app: app, servers: servers] do
      Rill.generate_necessary_modules(app, servers)

      use Application

      def start(_args, _opts) do
        structure = %{servers: unquote(Macro.escape(servers))}
        r = Rill.start(app: unquote(app), structure: structure)
        on_start()
        r
      end

      def on_start do
      end

      defoverridable on_start: 0
    end
  end

  def generate_necessary_modules(app, servers) do
    generate_server_alias_module(app, servers)
    generate_servers(app, servers)
  end

  defp generate_servers(app, servers) do
    for {module, [template: type]} <- servers do
      case type do
        :tcp ->
          generate_server_by_template("tcp.exs", app, module)

        :player ->
          generate_server_by_template("global_temporary.exs", app, module)

        :global_temporary ->
          generate_server_by_template("global_temporary.exs", app, module)

        :room ->
          generate_server_by_template("local_temporary.exs", app, module)

        :local_temporary ->
          generate_server_by_template("local_temporary.exs", app, module)

        :leaderboard ->
          generate_server_by_template("local_permanent.exs", app, module)

        :local_permanent ->
          generate_server_by_template("local_permanent.exs", app, module)
      end
    end
  end

  defp generate_server_alias_module(app, servers) do
    aliases = Enum.map(servers, fn e -> Module.concat(app, elem(e, 0)) end)

    defmodule Alias do
      @aliases aliases
      defmacro __using__(_) do
        quote do
          Rill.Alias.def_aliases(unquote(@aliases))
        end
      end

      defmacro def_aliases(as) do
        for a <- as do
          quote do
            alias unquote(a)
          end
        end
      end
    end
  end

  defp get_server_template_file_ast(file) do
    server_template_dir = to_string(:code.priv_dir(:rill)) <> "/rill/template/"
    code = EEx.eval_file(server_template_dir <> file)
    {:ok, quoted} = Code.string_to_quoted(code)
    quoted
  end

  defp modify_server_template_ast(quoted, app, module) do
    Macro.postwalk(quoted, fn e ->
      case e do
        {:__aliases__, c, [:Template, :Module]} ->
          {:__aliases__, c, [app, module]}

        {:__aliases__, c, [:Template, :Shore]} ->
          {:__aliases__, c, [app, :Shore, module]}

        _ ->
          e
      end
    end)
  end

  defp generate_server_by_template(file, app, module) do
    app = elixir_atom_to_pure_atom(app)
    module = elixir_atom_to_pure_atom(module)

    file
    |> get_server_template_file_ast
    |> modify_server_template_ast(app, module)
    |> Code.eval_quoted()
  end

  defp elixir_atom_to_pure_atom(a) do
    a
    |> to_string
    |> String.split(".")
    |> Enum.reverse()
    |> hd
    |> String.to_atom()
  end

  @spec start(Keyword.t()) :: {:ok, pid}
  def start(opts \\ []) do
    opts = enhance_opts(opts)
    {:ok, pid} = Rill.Supervisor.start_link(opts)
    Rill.Http.start(get_http_handlers(opts), opts)
    {:ok, pid}
  end

  defp enhance_opts(opts) do
    opts
    |> Keyword.update(:http_port, Application.get_env(:rill, :http_port, 8000), & &1)
    |> Keyword.update(:tcp_port, Application.get_env(:rill, :tcp_port, 8080), & &1)
  end

  defp get_http_handlers(opts) do
    if Keyword.has_key?(opts, :http_handlers) do
      Keyword.get(opts, :http_handlers)
    else
      app = Keyword.get(opts, :app)
      http_prefix = Atom.to_string(app) <> ".Http."
      module_names = get_all_module_names()

      http_handlers =
        Enum.filter(module_names, fn e ->
          String.starts_with?(Atom.to_string(e), http_prefix)
        end)

      if http_handlers == [] do
        defmodule DefaultHandler do
          use Rill.Http
        end

        [Rill.DefaultHandler]
      else
        http_handlers
      end
    end
  end

  defp get_all_module_names() do
    for {app, _, _} <- :application.loaded_applications(),
        {:ok, modules} = :application.get_key(app, :modules),
        module <- modules do
      module
    end
  end

  @spec find_pid(registered_name :: any()) :: pid() | nil
  def find_pid(registered_name) do
    case :global.whereis_name(registered_name) do
      pid when is_pid(pid) -> pid
      _ -> nil
    end
  end

  def handle_flow(shore, opts, %Rill.Flow.Msg{} = message, state) do
    flow = message.flow
    msg = message.content
    sm = message.sender_module
    s_pid = message.sender_pid
    delay = message.delay

    opts = Enum.into([f: flow, sm: sm, sp: s_pid, d: delay], opts)

    case shore.pre_handle(opts, msg, state) do
      {:ok, state} ->
        flow.handle(opts, msg, state)

      {:end, {:noreply, state}} ->
        {:noreply, state}

      {:end, {:reply, reply, state}} ->
        {:reply, reply, state}
    end
  end
end
