defmodule Rill.Http do
  defmacro __using__([]) do
    quote location: :keep do
      def get_router do
        {"/", __MODULE__, []}
      end

      def init(req, _) do
        header = %{<<"content-type">> => <<"text/plain">>}
        content = <<"Hello Visitor!">>

        req = :cowboy_req.reply(200, header, content, req)

        {:ok, req, :undefined}
      end

      defoverridable get_router: 0, init: 2
    end
  end

  def start(http_handlers, options) do
    app = Keyword.get(options, :app) |> Application.get_application()
    port = Keyword.get(options, :http_port)
    opts = [{:port, port}, {:max_connections, :infinity}]

    static_handler = {"/static/[...]", :cowboy_static, {:priv_dir, app, "static"}}
    custom_handlers = Enum.map(http_handlers, & &1.get_router)

    dispatch = :cowboy_router.compile([{:_, [static_handler | custom_handlers]}])
    
    env = %{env: %{dispatch: dispatch}}
    :cowboy.start_clear(:my_http_listener, opts, env)
  end
end
