defmodule TplinkSmartplugmon.PlugWatcher do
  use GenServer

  require Logger

  @default_poll_interval_ms 5000

  def start_link(host, monitor_app_dir, opts \\ []) do
    GenServer.start_link(__MODULE__, [host, monitor_app_dir, opts], opts)
  end

  def init([host, monitor_app_dir, opts]) do
    poll_interval = opts[:poll_interval] || @default_poll_interval_ms

    state = %{
      host: host,
      app_dir: monitor_app_dir,
      poll_interval: poll_interval
    }

    Process.send_after(self(), :poll, 0)

    {:ok, state}
  end

  def handle_info(:poll, state) do
    poll(state.host, state.app_dir, state.poll_interval)

    {:noreply, state}
  end

  defp poll(host, app_dir, poll_interval) do
    {output, 0} = System.cmd("#{app_dir}/tplink_smartplug.py", ["-t", host, "-c", "energy"])
    # Sent:      {"emeter":{"get_realtime":{}}}
    # Received:  {"emeter":{"get_realtime":{"current":3.548681,"voltage":122.102035,"power":417.532206,"total":17.696000,"err_code":0}}}

    [_, result] = String.split(output, "Received:", trim: true)

    {output, 0} = System.cmd("#{app_dir}/tplink_smartplug.py", ["-t", host, "-c", "info"])
    [_, info] = String.split(output, "Received:", trim: true)

    info = Poison.decode!(info)
    plug_id = info["system"]["get_sysinfo"]["alias"]

    Poison.decode!(result)
    |> post_report(plug_id)

    Process.send_after(self(), :poll, poll_interval)
  end

  defp post_report(report, plug_id) do
    realtime = report["emeter"]["get_realtime"]

    Stakmon.Application.gauge("smartplug.current.amps", realtime["current"], tags: ["plug_id:#{plug_id}"])
    Stakmon.Application.gauge("smartplug.power.watts", realtime["power"], tags: ["plug_id:#{plug_id}"])
    Stakmon.Application.gauge("smartplug.total_usage", realtime["total"], tags: ["plug_id:#{plug_id}"])
  end
end
