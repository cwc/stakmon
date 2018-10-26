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
    if config[:stak_watchers] do
      Enum.each(config.stak_watchers, fn watcher ->
        Stakmon.start_stak_watcher(watcher)
        |> inspect
        |> Logger.info
      end)
    end

    if config[:srbminer_watchers] do
      Enum.each(config.srbminer_watchers, fn watcher ->
        Srbminermon.start_watcher(watcher)
        |> inspect
        |> Logger.info
      end)
    end

    if config[:tplink_smartplug_dir] do
      Enum.each(config.tplink_smartplug_watchers, fn watcher->
        TplinkSmartplugmon.start_watcher(config.tplink_smartplug_dir, watcher)
        |> inspect
        |> Logger.info
      end)
    end
  end
end
