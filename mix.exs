defmodule Goodies.MixProject do
  use Mix.Project

  def project do
    [
      app: :goodies,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      env: [
        source_dir: {:app, "priv/sources"}
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # QA tools
      {:credo, ">= 0.0.0", runtime: false},
      {:dialyxir, "~> 1.1.0", runtime: false},
      {:ex_doc, ">= 0.0.0", runtime: false},
      {:httpoison, "~> 1.8"},
      {:mint, "~> 1.4.0"},
      {:jason, ">= 0.0.0"},
      {:zstream, "~> 0.6"},
      {:castore, ">= 0.0.0"},
      {:progress_bar, "~> 2.0"}
    ]
  end

  defp dialyzer do
    [
      plt_ignore_apps: [:credo],
      ignore_warnings: ".dialyzer/ignore.exs",
      plt_file: {:no_warn, ".dialyzer/cache.plt"}
    ]
  end
end
