defmodule Rigmon do
  def start_rig_watcher({rig_id, _, _} = rig_spec) do
    Supervisor.start_child(Rigmon.Supervisor, %{
      id: rig_id,
      start: {Rigmon.RigWatcher, :start_link, [rig_spec]}
    })
  end
end

defmodule Rigmon.RigWatcher do
  use GenServer

  require Logger

  def start_link(rig_spec) do
    GenServer.start_link(__MODULE__, rig_spec)
  end

  def init({rig_id, miner_spec, plug_spec}) do
    Logger.info("Monitoring rig #{rig_id}")

    {miner_mod, start_args} = miner_spec
    miner_pid = Kernel.apply(miner_mod, :start_watcher, [start_args])
    |> inspect
    |> Logger.debug

    config = Application.get_env(:stakmon, :config)
    plug_pid = TplinkSmartplugmon.start_watcher(config.tplink_smartplug_dir, plug_spec)
    |> inspect
    |> Logger.debug

    {:ok, %{
      rig_id: rig_id,
      miner_pid: miner_pid,
      plug_pid: plug_pid,
    }}
  end
end

