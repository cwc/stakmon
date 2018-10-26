defmodule Stakmon.Mixfile do
  use Mix.Project

  def project do
    [
      app: :stakmon,
      version: "0.1.0",
      elixir: "~> 1.7.3",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Stakmon.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpotion, "~> 3.0.2"},
      {:poison, "~> 3.1"},
      {:statix, "~> 1.1.0"},
    ]
  end
end
