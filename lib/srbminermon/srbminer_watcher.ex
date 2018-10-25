defmodule Srbminermon.SrbminerWatcher do
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

  defp poll(state, hostname, port) do
    case HTTPotion.get("http://#{hostname}:#{port}") do
      %{status_code: 200, body: body} -> body |> Poison.decode! |> post_report(state)

      resp -> Logger.error("Response from #{hostname}:#{port}: #{inspect resp}")
    end
  end

  def handle_info(:poll, state) do
    poll(state, state.hostname, state.port)

    Process.send_after(self(), :poll, state.poll_interval)

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def post_report(api_results, state) do
	Stakmon.Application.gauge("hashrate.total.10s", api_results["hashrate_total_now"], tags: ["pool:#{api_results["pool"]["pool"]}", "hostname:#{state.hostname}"])
	Stakmon.Application.gauge("hashrate.total.60s", api_results["hashrate_total_1min"], tags: ["pool:#{api_results["pool"]["pool"]}", "hostname:#{state.hostname}"])

	Stakmon.Application.gauge("shares.good", api_results["shares"]["accepted"], tags: ["pool:#{api_results["pool"]["pool"]}", "hostname:#{state.hostname}"])
	Stakmon.Application.gauge("shares.total", api_results["shares"]["total"], tags: ["pool:#{api_results["pool"]["pool"]}", "hostname:#{state.hostname}"])

	{:noreply, state}
  end
end
