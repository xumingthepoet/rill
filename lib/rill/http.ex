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
    port = Keyword.get(options, :http_port)
    opts = [{:port, port}, {:max_connections, :infinity}]
    dispatch = :cowboy_router.compile([{:_, http_handlers |> Enum.map(& &1.get_router)}])
    env = %{env: %{dispatch: dispatch}}
    :cowboy.start_clear(:my_http_listener, opts, env)
  end
end
