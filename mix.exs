defmodule Rill.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rill,
      version: File.read("VERSION") |> elem(1),
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      #mod: {E, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # aws
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.6"},

      # json
      {:json, "~> 1.0"},

      # webserver
      {:cowboy, "~> 2.0.0"},

      # releases
      {:distillery, "~> 1.5", runtime: false}
    ]
  end
end
