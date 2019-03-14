defmodule Rigmon do
  def start_rig_watcher({rig_id, _, _} = rig_spec) do
    Supervisor.start_child(Rigmon.Supervisor, %{
      id: rig_id,
      start: {Rigmon.RigWatcher, :start_link, [rig_spec]}
    })
  end

  def miner_poll_error(pid) do
    GenServer.cast(pid, :miner_poll_error)
  end
end
