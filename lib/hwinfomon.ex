defmodule Hwinfomon do
  def start_hwinfo_watcher(hostname, port, opts \\ []) do
    Supervisor.start_child(Stakmon.HwinfoWatcher.Supervisor, %{
      id: "#{hostname}:#{port}",
      start: {Hwinfomon.HwinfoWatcher, :start_link, [hostname, port, opts]}
    })
  end

  def stop_hwinfo_watcher(hostname, port) do
    :ok = Supervisor.terminate_child(Stakmon.HwinfoWatcher.Supervisor, "#{hostname}:#{port}")
    Supervisor.delete_child(Stakmon.HwinfoWatcher.Supervisor, "#{hostname}:#{port}")
  end

  def list_watchers do
    Supervisor.which_children(Stakmon.HwinfoWatcher.Supervisor)
    |> Enum.map(fn w ->
      [host, port] = String.split(elem(w, 0), ":")

      [host, String.to_integer(port)]
    end)
  end
end
