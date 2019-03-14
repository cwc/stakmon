defmodule TplinkSmartplugmon do
  require Logger

  def start_watcher(monitor_app_dir, {host, port, opts}), do: start_watcher(monitor_app_dir, {host, port}, opts)
  def start_watcher(monitor_app_dir, {host, opts}) when is_list(opts), do: start_watcher(monitor_app_dir, host, opts)
  def start_watcher(monitor_app_dir, host, opts \\ []) do
    Logger.info("Starting TP-Link plug watcher for #{inspect(host)}")
    Supervisor.start_child(Stakmon.TplinkSmartplugmon.Supervisor, %{
      id: host,
      start: {TplinkSmartplugmon.PlugWatcher, :start_link, [host, monitor_app_dir, opts]}
    })
  end

  def stop_watcher(host) do
    :ok = Supervisor.terminate_child(Stakmon.TplinkSmartplugmon.Supervisor, host)
    Supervisor.delete_child(Stakmon.TplinkSmartplugmon.Supervisor, host)
  end

  def list_watchers do
    Supervisor.which_children(Stakmon.TplinkSmartplugmon.Supervisor)
    |> Enum.map(fn w ->
      elem(w, 0)
    end)
  end

  def power_off(pid) do
    GenServer.cast(pid, :power_off)
  end

  def power_on(pid) do
    GenServer.cast(pid, :power_on)
  end
end
