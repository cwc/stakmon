defmodule Rigmon.RigWatcher do
  use GenServer

  require Logger

  @reset_threshold_s 90

  def start_link(rig_spec) do
    GenServer.start_link(__MODULE__, rig_spec)
  end

  def init({rig_id, miner_spec, plug_spec}) do
    Logger.info("Monitoring rig #{rig_id}")

    {miner_mod, start_args} = miner_spec
    {:ok, miner_pid} = Kernel.apply(miner_mod, :start_watcher, [start_args, self()])

    miner_pid |> inspect
    |> Logger.debug

    config = Application.get_env(:stakmon, :config)
    {:ok, plug_pid} = TplinkSmartplugmon.start_watcher(config.tplink_smartplug_dir, plug_spec)

    plug_pid |> inspect
    |> Logger.debug

    {:ok, %{
      rig_id: rig_id,
      miner_mod: miner_mod,
      miner_pid: miner_pid,
      plug_mod: TplinkSmartplugmon,
      plug_pid: plug_pid,
      last_reset: (DateTime.utc_now |> DateTime.to_unix) - 60,
    }}
  end

  def handle_cast(:miner_poll_error, state) do
    now = DateTime.utc_now |> DateTime.to_unix

    if now - state.last_reset > @reset_threshold_s do
      Logger.info(~s(Poll error for #{state.rig_id}: resetting rig))

      Kernel.apply(state.plug_mod, :power_off, [state.plug_pid])
      Kernel.apply(state.plug_mod, :power_on, [state.plug_pid])

      {:noreply, Map.put(state, :last_reset, now)}
    else
      {:noreply, state}
    end
  end
end

