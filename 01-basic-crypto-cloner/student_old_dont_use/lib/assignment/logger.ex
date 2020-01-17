defmodule Assignment.Logger do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def log(message) do
    GenServer.cast(__MODULE__, {:log, message})
  end
  def log(level, message) when level in [:warn, :info, :debug, :error] do
    l = String.upcase(Atom.to_string(level))
    GenServer.cast(__MODULE__, {:log, "[#{l}] #{message}"})
  end
  def handle_cast({:log, message}, state) do
    IO.puts("#{message}")
    {:noreply, state}
  end
end
