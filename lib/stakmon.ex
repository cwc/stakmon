defmodule Stakmon do
  require Logger

  def start_stak_watcher({hostname, port}), do: start_stak_watcher(hostname, port)
  def start_stak_watcher({hostname, port, opts}), do: start_stak_watcher(hostname, port, opts)
  def start_stak_watcher(hostname, port, opts \\ []) do
    Logger.info("Starting StakWatcher for #{hostname}:#{port}")
    Supervisor.start_child(Stakmon.StakWatcher.Supervisor, %{
      id: "#{hostname}:#{port}",
      start: {Stakmon.StakWatcher, :start_link, [hostname, port, opts]}
    })
  end

  def stop_stak_watcher(hostname, port) do
    :ok = Supervisor.terminate_child(Stakmon.StakWatcher.Supervisor, "#{hostname}:#{port}")
    Supervisor.delete_child(Stakmon.StakWatcher.Supervisor, "#{hostname}:#{port}")
  end

  def list_watchers do
    Supervisor.which_children(Stakmon.StakWatcher.Supervisor)
    |> Enum.map(fn w ->
      [host, port] = String.split(elem(w, 0), ":")

      [host, String.to_integer(port)]
    end)
  end
end
