defmodule Hwinfomon.HwinfoWatcher do
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
    case HTTPotion.get("http://#{hostname}:#{port}") do
      %{status_code: 200, body: body} -> body |> Poison.decode! |> post_report

      resp -> Logger.error("Response from #{hostname}:#{port}: #{inspect resp}")
    end

    Process.send_after(self(), :poll, poll_interval)
  end

  defp post_report(report) do
    send(self(), {:report, report})
  end

  def handle_info(:poll, state) do
    poll(state.hostname, state.port, state.poll_interval)

    {:noreply, state}
  end

  def handle_info({:report, report}, state) do
    Enum.each(report, fn sensor ->
      gpu_regex = ~r/GPU \[#(?<gpu_id>\d+)\]: (?<gpu_name>.*): /

      case Regex.named_captures(gpu_regex, sensor["SensorClass"]) do
        nil -> :ok

        %{"gpu_name" => gpu_name, "gpu_id" => gpu_id} ->
          # This is a GPU sensor; if it's a metric we care about, post it
          gpu = gpu_name <> "-" <> gpu_id
          name = sensor["SensorName"]
          value = sensor["SensorValue"]

          if String.contains?(name, "GPU Thermal Diode"), do: Stakmon.Application.gauge("gpu.temp", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if String.contains?(name, "HBM Temp"), do: Stakmon.Application.gauge("gpu.hbm.temp", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if String.contains?(name, "GPU Clock"), do: Stakmon.Application.gauge("gpu.clock", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if String.contains?(name, "GPU Memory Clock"), do: Stakmon.Application.gauge("gpu.memory.clock", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if String.contains?(name, "GPU SoC Clock"), do: Stakmon.Application.gauge("gpu.soc.clock", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if String.contains?(name, "GPU Core Voltage"), do: Stakmon.Application.gauge("gpu.voltage", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if String.contains?(name, "GPU Memory Voltage"), do: Stakmon.Application.gauge("gpu.memory.voltage", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
          if name == "GPU Fan", do: Stakmon.Application.gauge("gpu.fan.rpm", value, tags: ["gpu:#{gpu}", "hostname:#{state.hostname}"])
      end
    end)

	{:noreply, state}
  end
  def handle_info(_, state), do: {:noreply, state}
end
