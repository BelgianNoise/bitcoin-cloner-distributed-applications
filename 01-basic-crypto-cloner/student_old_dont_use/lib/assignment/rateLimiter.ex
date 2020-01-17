defmodule Assignment.RateLimiter do
  use GenServer

  defstruct [ rate: Application.get_env(:assignment, :rate), queue: [] ]

  def start_link(_) do
    GenServer.start_link(__MODULE__,
      [], name: __MODULE__)
  end

  def init(_) do
    state = %__MODULE__{ }
    send(self(), :tick)
    {:ok, state}
  end

  def change_rate_limit(new_rate) do
    GenServer.cast(__MODULE__, {:set_rate, new_rate})
  end

  def handle_cast({:set_rate, newRate}, state) do
    new_state = %{ state | rate: newRate }
    {:noreply, new_state}
  end

  def handle_cast({:request_permission, pid}, state) do
    new_state = %{ state | queue: state.queue ++ [pid] }
    {:noreply, new_state}
  end

  def request_permission(pid) do
    GenServer.cast(__MODULE__, {:request_permission, pid})
  end

  def handle_info(:tick, state = %__MODULE__{ queue: [] }) do
    tijdje = round(1000 / state.rate)
    Process.send_after(self(), :tick, tijdje)
    {:noreply, state}
  end

  def handle_info(:tick, state = %__MODULE__{ queue: [x | xs] }) do
    if (Process.alive?(x)) do
      send(x, :go)
    end
    tijdje = round(1000 / state.rate)
    Process.send_after(self(), :tick, tijdje)
    new_state = %{state | queue: xs}
    {:noreply, new_state}
  end
end
