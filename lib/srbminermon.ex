defmodule Srbminermon do
  def start_watcher(hostname, port, opts \\ []) do
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
