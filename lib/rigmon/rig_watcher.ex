defmodule Rigmon.RigWatcher do
  use GenServer

  require Logger

  @reset_threshold_s 120
  @power_on_delay_ms 200

  def start_link(rig_spec) do
    GenServer.start_link(__MODULE__, rig_spec)
  end

  def init(rig_spec = {_, _, _}), do: init(Tuple.append(rig_spec, []))
  def init({rig_id, miner_spec, plug_spec, options}) do
    Logger.info("Monitoring rig #{rig_id}")

    {miner_mod, start_args} = miner_spec
    miner_pid = case Kernel.apply(miner_mod, :start_watcher, [start_args, self()]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end

    miner_pid |> inspect
    |> Logger.debug

    config = Application.get_env(:stakmon, :config)
    plug_pid = case TplinkSmartplugmon.start_watcher(config.tplink_smartplug_dir, plug_spec) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end

    plug_pid |> inspect
    |> Logger.debug

    {:ok, %{
      rig_id: rig_id,
      miner_mod: miner_mod,
      miner_pid: miner_pid,
      plug_mod: TplinkSmartplugmon,
      plug_pid: plug_pid,
      last_reset: (DateTime.utc_now |> DateTime.to_unix) - @reset_threshold_s - 1,
      auto_reset: options[:auto_reset],
    }}
  end

  def handle_cast(:miner_poll_error, state) do
    now = DateTime.utc_now |> DateTime.to_unix

    if state.auto_reset && now - state.last_reset > @reset_threshold_s do
      Logger.info(~s(Poll error for #{state.rig_id}: resetting rig))

      Kernel.apply(state.plug_mod, :power_off, [state.plug_pid])
      Process.sleep(@power_on_delay_ms)
      Kernel.apply(state.plug_mod, :power_on, [state.plug_pid])

      {:noreply, Map.put(state, :last_reset, now)}
    else
      {:noreply, state}
    end
  end
end
