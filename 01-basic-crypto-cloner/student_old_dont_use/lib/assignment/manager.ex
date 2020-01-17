defmodule Assignment.ProcessManager do
  use GenServer

  defstruct [ children: [] , info: nil]

  def start_link(info) do
    GenServer.start_link(__MODULE__, info, name: __MODULE__)
  end

  def init(inf) do
    state = %__MODULE__{children: [], info: inf}
    {:ok, state, {:continue, :start_children}}
  end

  def handle_continue(:start_children, state) do
    lijstje = Supervisor.which_children(Assignment.CoindataRetrieverSupervisor)
    if(length(lijstje) != 0) do
      new_lijstje = Enum.map(lijstje, fn {_,pid, _, _} ->
        pair = Assignment.CoindataRetriever.get_pair_for(pid)
        {List.keyfind(pair, :pair, 0)|>elem(1), pid}
      end)
      # Enum.each(new_lijstje, fn {_pair, piddd} ->
      #   Process.monitor(piddd)
      # end)
      new_state = %{state | children: new_lijstje}
      {:noreply, new_state}
    else
      pairs = retrieve_coin_pairs()
      Enum.each(pairs, fn pair ->
        Assignment.CoindataRetrieverSupervisor.start_child(pair)
      end)
      {:noreply, state}
    end
  end

  def retrieve_coin_pairs() do
    url = "https://poloniex.com/public?command=returnTicker"
    {:ok, response} = Tesla.get(url)
    decodedeBody = response.body|>Jason.decode!()
    _coinPairs = decodedeBody|>Enum.map(fn {
      key, _value
    } -> key end)
  end

  def handle_call(:get_alles, _sender , state) do
    {:reply, state.children, state}
  end
  def retrieve_coin_processes() do
    GenServer.call(__MODULE__, :get_alles)
  end

  def handle_cast({:add_pid, {pair, pid}}, state) do
    # Process.monitor(pid)
    res = Enum.find(state.children, fn {pr, _p} ->
      pr == List.keyfind(pair, :pair, 0)|>elem(1)
    end)
    if res != nil do
      new_children = List.keyreplace(state.children,
        List.keyfind(pair, :pair, 0)|>elem(1), 0,
          {List.keyfind(pair, :pair, 0)|>elem(1), pid})
      Assignment.Logger.log(:info, "updated pid for: #{inspect pair}")
      new_state = %{state | children: new_children}
      {:noreply, new_state}
    else
      Assignment.Logger.log(:info, "#{inspect pid} added to ProcessManager's children")
      new_state = %{ state |
      children: state.children ++ [{List.keyfind(pair, :pair, 0)|>elem(1), pid}] }
      {:noreply, new_state}
    end
  end

  def add_entry(pair, pid) do
    GenServer.cast(__MODULE__, {:add_pid, {pair, pid}})
  end

  # def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
  #  {pair, _old_pid} = List.keyfind(state.children, pid, 1)
  #  Assignment.CoindataRetrieverSupervisor.start_child(pair)
  #  {:noreply, state}
  # end
end
