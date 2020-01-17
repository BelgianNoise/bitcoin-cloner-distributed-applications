defmodule Assignment.CoindataCoordinator do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil,
      name: {:global, {Node.self(), __MODULE__}})
  end

  def init(_) do
    state = __MODULE__
    {:ok, state, {:continue, :start_children}}
  end
  # Met argument om ni elke keer te checken
  # of alle pairs aan het runnen zijn
  # zou niveel nut hebben ma wel langer duren
  def balance(checkIfAllPairsAreRunning \\ true) do
    IO.puts "Node: #{inspect node()} started balancing!"
    nodes = [node() | Node.list()]
    if(checkIfAllPairsAreRunning) do
      # deze gaat 1x worden opgeroepen bij balance()
      IO.puts "Checking if all pairs are running..."
      totalAmountOfRunningPairs =
        get_total_amount_of_running_pairs(nodes)
      all_pairs = retrieve_coin_pairs()
      if(length(all_pairs) > totalAmountOfRunningPairs) do
        temp = get_all_running_pairs(nodes)
        all_running_pairs = Enum.map(temp, fn {p,_} -> p end)
        not_running_pairs = all_pairs -- all_running_pairs
        IO.puts "#{inspect length(not_running_pairs)} Pairs are not running, let's fix that!"
        # op deze node nu al deze processen starten en die worden
        # daarna direct gedistribute naar andere nodes lekker
        Enum.each(not_running_pairs, fn pair ->
          Assignment.CoindataRetrieverSupervisor.start_child(pair)
        end)
        # Ik doe deze in een aparte Enum.each om
        # bepaalde problemen te voorkomen met timing
        Enum.each(not_running_pairs, fn pair ->
          Assignment.HistoryKeeperWorkerSupervisor.start_child(pair)
        end)
        IO.puts "All pairs were restarted on this node! Getting ready to distribute pairs..."
        :timer.sleep(3000)
      else
        IO.puts "#{inspect length(all_pairs)}/#{inspect length(all_pairs)} pairs are running somewhere on a node!"
      end
    end
    amountOfNodes = Enum.count(nodes)
    IO.puts "Amount of active nodes: #{inspect amountOfNodes}"
    IO.puts "List of active nodes: #{inspect nodes}"
    structList = get_structured_list_of_nodes(nodes)
    # [{name, pid, runningPairs}, ...]
    print_stats(structList)
    {busiest_nodename, busy_pid, busiest_amount} =
         get_busiest_nodename(structList)
    {unbusiest_nodename, _unbusy_pid, unbusiest_amount} =
      get_unbusiest_nodename(structList)
    pair = GenServer.call(busy_pid, :get_owned_pair)
    diff_in_runningPairs = busiest_amount - unbusiest_amount
    if(busiest_nodename != unbusiest_nodename &&
                 diff_in_runningPairs > 2) do
      IO.puts "Transfering #{inspect pair} from #{inspect busiest_nodename} to #{inspect unbusiest_nodename}"
      GenServer.cast(
        busy_pid,
        {:transfer, pair, unbusiest_nodename}
      )
      # hier false voor ni opnieuw te checken of alle pairs runnen
      IO.puts "================================================================"
      balance(false)
    else
      IO.puts "All pairs are perfectly distributed right now!"
      IO.puts "================================================================"
    end
  end

  def get_all_running_pairs(nodes) do
    if(length(nodes) < 1) do
      []
    else
      [head | tail] = nodes
      pidNode = :global.whereis_name(
        {head, Assignment.CoindataCoordinator}
      )
      pairs = GenServer.call(
        pidNode,
        :retrieve_all_coin_pids
      )
      val = pairs
      List.flatten([val, get_all_running_pairs(tail)])
    end
  end
  def get_busiest_nodename(list) do
    if(length(list) >= 2) do
      # we hebben onze tail nog nodig voor recursie
      [head | tail] = list
      [second | _tail2] = tail
      {_name, _pid, amount} = head
      {_name2, _pid2, amount2} = second
      # het max vinden ?
      ma = max(amount, amount2)
      # de return value veranderen
      if(ma == amount2) do
        tempres = second
        res2 = get_busiest_nodename(tail)
        {_nameres1, _pid1, amountres1} = tempres
        {_nameres2, _pid2, amountres2} = res2
        ma2 = max(amountres1, amountres2)
        if(ma2 == amountres1) do
          tempres
        else
          res2
        end
      else
        tempres = head
        res2 = get_busiest_nodename(tail)
        {_nameres1, _pid1, amountres1} = tempres
        {_nameres2, _pid2, amountres2} = res2
        ma2 = max(amountres1, amountres2)
        if(ma2 == amountres1) do
          tempres
        else
          res2
        end
      end
    else
     [head | _tail] = list
     head
    end
  end

  def get_unbusiest_nodename(list) do
    if(length(list) >= 2) do
      # we hebben onze tail nog nodig voor recursie
      [head | tail] = list
      [second | _tail2] = tail
      {_name, _pid, amount} = head
      {_name2, _pid2, amount2} = second
      # het max vinden ?
      mi = min(amount, amount2)
      # de return value veranderen
      if(mi == amount2) do
        tempres = second
        res2 = get_unbusiest_nodename(tail)
        {_nameres1, _pid1, amountres1} = tempres
        {_nameres2, _pid2, amountres2} = res2
        mi2 = min(amountres1, amountres2)
        if(mi2 == amountres1) do
          tempres
        else
          res2
        end
      else
        tempres = head
        res2 = get_unbusiest_nodename(tail)
        {_nameres1, _pid1, amountres1} = tempres
        {_nameres2, _pid2, amountres2} = res2
        mi2 = min(amountres1, amountres2)
        if(mi2 == amountres1) do
          tempres
        else
          res2
        end
      end
    else
     [head | _tail] = list
     head
    end
  end
  def print_stats(list) do
    if(length(list) >= 1) do
      [head | tail] = list
      {name, _pid, amount} = head
      IO.puts "There are #{amount} pairs running on node #{name}"
      print_stats(tail)
    end
  end
  def get_total_amount_of_running_pairs(nodes) do
    if(length(nodes) < 1) do
      0
    else
      [head | tail] = nodes
      pidNode = :global.whereis_name(
        {head, Assignment.CoindataCoordinator}
      )
      amountOfRunningPairs = length(GenServer.call(
        pidNode,
        :retrieve_all_coin_pids
      ))
      val = amountOfRunningPairs
      val + get_total_amount_of_running_pairs(tail)
    end
  end
  def get_structured_list_of_nodes(nodes) do
    if(length(nodes) < 1) do
      []
    else
      [head | tail] = nodes
      pidNode = :global.whereis_name(
        {head, Assignment.CoindataCoordinator}
      )
      amountOfRunningPairs = length(GenServer.call(
        pidNode,
        :retrieve_all_coin_pids
      ))
      val = {head, pidNode, amountOfRunningPairs}
      List.flatten([val,get_structured_list_of_nodes(tail)])
    end
  end

  def handle_call(:retrieve_all_coin_pids, _from, state) do
    {:reply, retrieve_all_coin_pids(), state}
  end
  def handle_call(:get_owned_pair, _from, state) do
    [head | _tail] = Registry.select(Assignment.Coindata.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    {pair, _pid} = head
    {:reply, pair, state}
  end
  def handle_cast({:transfer, pair, nodename}, state) do
    transfer_pair_to_node(pair, nodename)
    {:noreply, state}
  end
  def transfer_pair_to_node(p, name) do
    # gegevens ophalen
    history_pid_here = get_pid_for_historyKeeper(p)
    {_, hist} = GenServer.call(history_pid_here, :history)
    fra = GenServer.call(history_pid_here, :get_frames)
    # proces daar opstarten
    _pidNewWorker = Node.spawn_link(name,
      fn -> Assignment.HistoryKeeperWorkerSupervisor
      .start_child(p, hist, fra)
    end)
    # proces daar opstarten
    _pidNewRetriever = Node.spawn_link(name, fn ->
      Assignment.CoindataRetrieverSupervisor.start_child(p)
    end)
    # processen hier stoppen
    Assignment.CoindataRetriever.stop(p)
    Assignment.HistoryKeeperWorker.stop(p)
  end

  def get_pid_for_coindata(pair) do
    list = retrieve_all_coin_pids()
    pid = list |> Enum.into(%{}) |> Map.fetch!(pair)
    pid
  end

  def get_pid_for_historyKeeper(pair) do
    list = retrieve_all_registry_workerkeys()
    pid = list |> Enum.into(%{}) |> Map.fetch!(pair)
    pid
  end

  def retrieve_all_coin_pids() do
    Registry.select(Assignment.Coindata.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  def retrieve_all_registry_workerkeys() do
    Registry.select(Assignment.History.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  def handle_continue(:start_children, state) do
    length = length(Node.list())
    if(length < 1) do
      if(length < 1) do
        pairs = retrieve_coin_pairs()
        Enum.each(pairs, fn pair ->
          Assignment.HistoryKeeperWorkerSupervisor.start_child(pair)
        end)
      end
      :timer.sleep(500)
      lijstje = Supervisor.which_children(Assignment.CoindataRetrieverSupervisor)
      if(length(lijstje) != 0) do
        new_lijstje = Enum.map(lijstje, fn {_,pid, _, _} ->
          pair = Assignment.CoindataRetriever.get_pair_for(pid)
          {List.keyfind(pair, :pair, 0)|>elem(1), pid}
        end)
        new_state = %{state | children: new_lijstje}
        {:noreply, new_state}
      else
        pairs = retrieve_coin_pairs()
        Enum.each(pairs, fn pair ->
          Assignment.CoindataRetrieverSupervisor.start_child(pair)
        end)
        {:noreply, state}
      end
    else
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
end
