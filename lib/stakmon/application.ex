defmodule Stakmon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Statix, runtime_config: true

  require Logger

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
      %{id: Rigmon.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Rigmon.Supervisor]]}
      },

      %{id: Stakmon.StakWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.StakWatcher.Supervisor]]}
      },

      %{id: Srbminermon.SrbminerWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Srbminermon.SrbminerWatcher.Supervisor]]}
      },

      %{id: Stakmon.HwinfoWatcher.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.HwinfoWatcher.Supervisor]]}
      },

      %{id: Stakmon.TplinkSmartplugmon.Supervisor,
        start: {Supervisor, :start_link, [[], [strategy: :one_for_one, name: Stakmon.TplinkSmartplugmon.Supervisor]]}
      },
    ]

    opts = [strategy: :one_for_one, name: Stakmon.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Load config
    {config, _} = Code.eval_string(File.read!("config.exs"))
    Application.put_env(:stakmon, :config, config)

    init_from_config(config)

    {:ok, pid}
  end

  def init_from_config(config) do
    if config[:rig_watchers] do
      Enum.each(config.rig_watchers, fn watcher ->
        Rigmon.start_rig_watcher(watcher)
        |> inspect
        |> Logger.info
      end)
    end
  end
end
