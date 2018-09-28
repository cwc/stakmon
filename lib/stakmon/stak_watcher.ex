defmodule Stakmon.StakWatcher do
  use GenServer

  require Logger

  @default_poll_interval_ms 5000

  def start_link(hostname, port, opts \\ []) do
    GenServer.start_link(__MODULE__, [hostname, port, opts], opts)
  end

  def init([hostname, port, opts]) do
    poll_interval = opts[:poll_interval] || @default_poll_interval_ms
    state = %{
      hostname: hostname,
      port: port,
      poll_interval: poll_interval
    }

    Process.send_after(self(), :poll, 0)

    {:ok, state}
  end

  defp poll(hostname, port, poll_interval) do
    case HTTPotion.get("http://#{hostname}:#{port}/api.json") do
      %{status_code: 200, body: body} -> body |> Poison.decode! |> wrap(hostname, port) |> post_report

      resp -> Logger.error("Response from #{hostname}:#{port}: #{inspect resp}")
    end

    Process.send_after(self(), :poll, poll_interval)
  end

  defp post_report(stak_report) do
    send(self(), {:stak_report, stak_report})
  end

  defp wrap(stak_report, hostname, port) do
    Map.put(stak_report, "_server", "#{hostname}:#{port}")
  end

  def handle_info(:poll, state) do
    poll(state.hostname, state.port, state.poll_interval)

    {:noreply, state}
  end

  def handle_info({:stak_report, stak_report}, state) do
	Stakmon.Application.gauge("hashrate.total.10s", stak_report["hashrate"]["total"] |> Enum.at(0), tags: ["pool:#{stak_report["connection"]["pool"]}", "hostname:#{state.hostname}:#{state.port}"])
	Stakmon.Application.gauge("hashrate.total.60s", stak_report["hashrate"]["total"] |> Enum.at(1), tags: ["pool:#{stak_report["connection"]["pool"]}", "hostname:#{state.hostname}:#{state.port}"])
	Stakmon.Application.gauge("hashrate.total.15m", stak_report["hashrate"]["total"] |> Enum.at(2), tags: ["pool:#{stak_report["connection"]["pool"]}", "hostname:#{state.hostname}:#{state.port}"])

	Stakmon.Application.gauge("shares.good", stak_report["results"]["shares_good"], tags: ["pool:#{stak_report["connection"]["pool"]}", "hostname:#{state.hostname}:#{state.port}"])
	Stakmon.Application.gauge("shares.total", stak_report["results"]["shares_total"], tags: ["pool:#{stak_report["connection"]["pool"]}", "hostname:#{state.hostname}:#{state.port}"])

	{:noreply, state}
  end
  def handle_info(_, state), do: {:noreply, state}
end
