defmodule TplinkSmartplugmon.PlugWatcher do
  use GenServer

  require Logger

  @default_poll_interval_ms 5000

  def start_link(host, monitor_app_dir, opts \\ []) do
    GenServer.start_link(__MODULE__, [host, monitor_app_dir, opts], opts)
  end

  def init([host_spec, monitor_app_dir, opts]) do
    poll_interval = opts[:poll_interval] || @default_poll_interval_ms
    statsd_tags = opts[:statsd_tags] || []

    {host, port} = case host_spec do
      {host, port} -> {host, port}
      host -> {host, 9999}
    end

    state = %{
      host: host,
      port: port,
      app_dir: monitor_app_dir,
      poll_interval: poll_interval,
      statsd_tags: statsd_tags
    }

    Process.send_after(self(), :poll, 0)

    {:ok, state}
  end

  def handle_info(:poll, state) do
    poll(state.host, state.port, state.app_dir, state)

    Process.send_after(self(), :poll, state.poll_interval)

    {:noreply, state}
  end

  def handle_cast(:power_off, state) do
    System.cmd("#{state.app_dir}/tplink_smartplug.py", ["-t", state.host, "-j", ~s({"system":{"set_relay_state":{"state":0}}}), "-p", state.port |> to_string])
    |> inspect
    |> Logger.debug

    {:noreply, state}
  end

  def handle_cast(:power_on, state) do
    System.cmd("#{state.app_dir}/tplink_smartplug.py", ["-t", state.host, "-j", ~s({"system":{"set_relay_state":{"state":1}}}), "-p", state.port |> to_string])
    |> inspect
    |> Logger.debug

    {:noreply, state}
  end

  defp poll(host, port, app_dir, state) do
    port = Integer.to_string(port)
    today = Date.utc_today

    # Get plug info
    {output, 0} = System.cmd("#{app_dir}/tplink_smartplug.py", ["-t", host, "-c", "info", "-p", port |> to_string])
    [_, info] = String.split(output, "Received:", trim: true)

    info = Poison.decode!(info)
    plug_id = info["system"]["get_sysinfo"]["alias"]

    # Get usage data
    {output, 0} = System.cmd("#{app_dir}/tplink_smartplug.py", ["-t", host, "-c", "energy", "-p", port |> to_string])
    # Sent:      {"emeter":{"get_realtime":{}}}
    # Received:  {"emeter":{"get_realtime":{"current":3.548681,"voltage":122.102035,"power":417.532206,"total":17.696000,"err_code":0}}}
    
    [_, result] = String.split(output, "Received:", trim: true)
    realtime = Poison.decode!(result)

    {output, 0} = System.cmd("#{app_dir}/tplink_smartplug.py", ["-t", host, "-j", ~s({"emeter":{"get_monthstat":{"year":#{today.year}}}}), "-p", port |> to_string])
    # Sent:      {"emeter":{"get_monthstat":{"year":2018}}}
    # Received:  {"emeter":{"get_monthstat":{"month_list":[{"year":2018,"month":10,"energy":0.021000}],"err_code":0}}}

    [_, result] = String.split(output, "Received:", trim: true)
    monthstat = Poison.decode!(result)

    # Send usage metrics
    Map.merge(realtime["emeter"], monthstat["emeter"])
    |> post_report(plug_id, state)
  end

  defp post_report(report, plug_id, state) do
    realtime = report["get_realtime"]
    base_tags = state.statsd_tags

    Stakmon.Application.gauge("smartplug.current.amps", realtime["current"], tags: base_tags ++ ["hostname:#{plug_id}"])
    Stakmon.Application.gauge("smartplug.power.watts", realtime["power"], tags: base_tags ++ ["hostname:#{plug_id}"])
    Stakmon.Application.gauge("smartplug.total_usage", realtime["total"], tags: base_tags ++ ["hostname:#{plug_id}"])

    month_list = report["get_monthstat"]["month_list"]

    Enum.each(month_list, fn month ->
      Stakmon.Application.gauge("smartplug.monthly_usage.kwh", month["energy"], tags: base_tags ++ ["hostname:#{plug_id}", "year:#{month["year"]}", "month:#{month["month"]}"])
    end)
  end
end
