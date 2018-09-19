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

    # Start supervision tree
    children = [
      %{id: Stakmon.StakWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.StakWatcher.Supervisor]]}
      },
      %{id: Stakmon.HwinfoWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.HwinfoWatcher.Supervisor]]}
      }
    ]

    opts = [strategy: :one_for_one, name: Stakmon.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Load config
    {config, _} = Code.eval_string(File.read!("config.json"))
    if config[:stakwatchers] do
      Enum.each(config.stakwatchers, fn {host, port} ->
        Stakmon.start_stak_watcher(host, port)
      end)
    end

    {:ok, pid}
  end
end
