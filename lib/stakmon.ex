defmodule Stakmon do
  def start_stak_watcher(hostname, port, opts \\ []) do
    Supervisor.start_child(Stakmon.StakWatcher.Supervisor, %{
      id: "#{hostname}:#{port}",
      start: {Stakmon.StakWatcher, :start_link, [hostname, port, opts]}
    })
  end

  def stop_stak_watcher(hostname, port) do
    :ok = Supervisor.terminate_child(Stakmon.StakWatcher.Supervisor, "#{hostname}:#{port}")
    Supervisor.delete_child(Stakmon.StakWatcher.Supervisor, "#{hostname}:#{port}")
  end
end
