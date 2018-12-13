defmodule Rill.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rill,
      version: "0.0.4",
      elixir: "~> 1.7",
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
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws_dynamo, "~> 2.0"},
      {:poison, "~> 3.1"},
      {:sweet_xml, "~> 0.6.5"},
      {:hackney, "~> 1.14"},

      # json
      {:json, "~> 1.2"},

      # webserver
      {:cowboy, "~> 2.4"},

    ]
  end
end
