defmodule Srbminermon.SrbminerWatcher do
  use GenServer

  require Logger

  @default_poll_interval_ms 5000

  def start_link(hostname, port, opts \\ []) do
    GenServer.start_link(__MODULE__, [hostname, port, opts], opts)
  end

  def init([hostname, port, opts]) do
    poll_interval = opts[:poll_interval] || @default_poll_interval_ms
    statsd_tags = opts[:statsd_tags] || []

    state = %{
      hostname: hostname,
      port: port,
      poll_interval: poll_interval,
      statsd_tags: statsd_tags,
      rigwatcher_pid: opts[:rigwatcher_pid],
    }

    Process.send_after(self(), :poll, 0)

    {:ok, state}
  end

  def handle_info(:poll, state) do
    poll(state, state.hostname, state.port)

    Process.send_after(self(), :poll, state.poll_interval)

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp poll(state, hostname, port) do
    case HTTPotion.get("http://#{hostname}:#{port}") do
      %{status_code: 200, body: body} -> body |> Poison.decode! |> post_report(state)

      resp ->
        Logger.error("Response from #{hostname}:#{port}: #{inspect resp}")
        poll_error(state)
    end
  end

  def poll_error(state) do
    if state.rigwatcher_pid do
      Rigmon.miner_poll_error(state.rigwatcher_pid)
    end
  end

  def post_report(api_results, state) do
    base_tags = state.statsd_tags ++ ["pool:#{api_results["pool"]["pool"]}", "hostname:#{state.hostname}"]

    Stakmon.Application.gauge("hashrate.total.10s", api_results["hashrate_total_now"], tags: base_tags)
    Stakmon.Application.gauge("hashrate.total.60s", api_results["hashrate_total_1min"], tags: base_tags)

    Stakmon.Application.gauge("shares.good", api_results["shares"]["accepted"], tags: base_tags)
    Stakmon.Application.gauge("shares.total", api_results["shares"]["total"], tags: base_tags)

    Enum.each(api_results["devices"], fn gpu ->
      Stakmon.Application.gauge("gpu.temp", gpu["temperature"], tags: ["gpu:#{gpu["device_id"]}"] ++ base_tags)
    end)

    {:noreply, state}
  end
end
