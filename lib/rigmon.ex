defmodule Rigmon do
  def start_rig_watcher(rig_spec) do
    Supervisor.start_child(Rigmon.Supervisor, %{
      id: elem(rig_spec, 0),
      start: {Rigmon.RigWatcher, :start_link, [rig_spec]}
    })
  end

  def miner_poll_error(pid) do
    GenServer.cast(pid, :miner_poll_error)
  end
end
