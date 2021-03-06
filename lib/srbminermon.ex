defmodule Srbminermon do
  require Logger

  def start_watcher({hostname, port}), do: start_watcher(hostname, port)
  def start_watcher({hostname, port, opts}), do: start_watcher(hostname, port, opts)
  def start_watcher({hostname, port, opts}, rigwatcher_pid), do: start_watcher(hostname, port, Keyword.put(opts, :rigwatcher_pid, rigwatcher_pid))
  def start_watcher(hostname, port, opts \\ []) do
    Logger.info("Starting SrbminerWatcher for #{hostname}:#{port}")
    Supervisor.start_child(Srbminermon.SrbminerWatcher.Supervisor, %{
      id: "#{hostname}:#{port}",
      start: {Srbminermon.SrbminerWatcher, :start_link, [hostname, port, opts]}
    })
  end

  def stop_watcher(hostname, port) do
    :ok = Supervisor.terminate_child(Srbminermon.SrbminerWatcher.Supervisor, "#{hostname}:#{port}")
    Supervisor.delete_child(Srbminermon.SrbminerWatcher.Supervisor, "#{hostname}:#{port}")
  end

  def list_watchers do
    Supervisor.which_children(Srbminermon.SrbminerWatcher.Supervisor)
    |> Enum.map(fn w ->
      [host, port] = String.split(elem(w, 0), ":")

      [host, String.to_integer(port)]
    end)
  end
end
