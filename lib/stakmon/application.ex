defmodule Stakmon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Statix, runtime_config: true

  def start(_type, _args) do
    # Configure metrics connection at runtime
    host = System.get_env("STATSD_HOST") || "localhost"
    port = (System.get_env("STATSD_PORT") || "8125") |> Integer.parse |> elem(0)

    Application.put_env(:statix, :host, host)
    Application.put_env(:statix, :port, port)
    Application.put_env(:statix, :prefix, "stakmon")

    {:ok, _} = Application.ensure_all_started(:statix)
    :ok = connect()

    children = [
      %{id: Stakmon.StakWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.StakWatcher.Supervisor]]}
      },
      %{id: Stakmon.HwinfoWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.HwinfoWatcher.Supervisor]]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Stakmon.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
