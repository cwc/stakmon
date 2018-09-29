defmodule TplinkSmartplugmon do
  def start_watcher(host, monitor_app_dir, opts \\ []) do
    Supervisor.start_child(Stakmon.TplinkSmartplugmon.Supervisor, %{
      id: host,
      start: {TplinkSmartplugmon.PlugWatcher, :start_link, [host, monitor_app_dir, opts]}
    })
  end

  def stop_watcher(host) do
    :ok = Supervisor.terminate_child(Stakmon.TplinkSmartplugmon.Supervisor, "#{host}")
    Supervisor.delete_child(Stakmon.TplinkSmartplugmon.Supervisor, "#{host}")
  end

  def list_watchers do
    Supervisor.which_children(Stakmon.TplinkSmartplugmon.Supervisor)
    |> Enum.map(fn w ->
      elem(w, 0)
    end)
  end
end
