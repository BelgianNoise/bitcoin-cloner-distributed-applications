defmodule Reporter.Reporter do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(state) do
    send(self(), :go)
    {:ok, state}
  end

  def handle_info(:go, state) do
    :timer.sleep(3000)
    nodes = Node.list
    struct_list = get_structured_list_of_nodes(nodes)
    listWithAmountOfHist = get_results(struct_list)
    listWithAmountOfHist2 = Enum.sort(listWithAmountOfHist,
    &(Enum.at(Tuple.to_list(&1),3) >=
    (Enum.at(Tuple.to_list(&2),3))))
    lekker_print(listWithAmountOfHist2)
    totalAmount = get_total_amount(struct_list)
    IO.puts "The total amount of pairs being cloned is: #{inspect totalAmount}"
    send(self(), :go)
    {:noreply, state}
  end
  def lekker_print(list) do
    # format van list {nodename, pair, aantalRecords}
    if length(list) < 1 do
      IO.puts "============================================================"
      IO.puts "NODE | PAIR       | PROGRESSION           |       | RECORDS"
    else
      [head | tail] = list
      {nodename, pair, aantalRecords, percent} = head
      temp = Regex.named_captures(
        ~r/node(?<foo>\d)@localhost/,
        Atom.to_string(nodename)
      )
      nodeOutput = "N" <> temp["foo"]
      pairOutput = " " <> parse_pairname(pair)
      {temp2, _} = Integer.parse(String.trim(percent))
      percentOutput = parse_percent(get_percent_output(temp2))
      IO.puts " #{nodeOutput}  |#{pairOutput}| #{percentOutput}  | #{percent} % | #{aantalRecords}"
      lekker_print(tail)
    end
  end
  def get_percent_output(percent) do
    if percent < 5 do
      ""
    else
      "X" <> get_percent_output(percent - 5)
    end
  end
  def parse_percent(perc) do
    if String.length(perc) < 20 do
      parse_percent(perc <> "-")
    else
      perc
    end
  end
  def get_total_amount(struct_list) do
    if (length(struct_list) < 1) do
      0
    else
      [head | tail] = struct_list
      {_nodename, _nodePid, workers} = head
      length(workers) + get_total_amount(tail)
    end
  end
  def parse_pairname(pair) do
    if String.length(pair) < 11 do
      parse_pairname(pair <> " ")
    else
      pair
    end
  end
  def get_results(struct_list) do
    if (length(struct_list) < 1) do
      []
    else
      [head | tail] = struct_list
      {nodename, _nodePid, workers} = head
      if length(workers) < 1 do
        # Deze node heeft nog geen workers
        List.flatten([get_results(tail)])
      else
        res = get_status_of_workers(workers, nodename)
        List.flatten([res, get_results(tail)])
      end
    end
  end
  def get_status_of_workers(workers, nodename) do
    if(length(workers) < 1) do
      []
    else
      [firstPair | others] = workers
      {pair, workerPid} = firstPair
      aantalRecords = length(
        GenServer.call(workerPid, :history) |> elem(1)
      )
      frames = GenServer.call(workerPid, :get_frames)
      percent = get_percent(frames)
      res = {nodename, pair, aantalRecords, percent}
      List.flatten([res, get_status_of_workers(others, nodename)])
    end
  end
  def get_percent(frames) do
    begin = Application.get_env(:assignment, :from)
    eind = Application.get_env(:assignment, :until)
    totalDuration = eind - begin
    durationToGo = get_percent_helper(frames)
    temp = trunc(((totalDuration - durationToGo) / totalDuration) * 100)
    if(temp < 10) do
      "  " <> Integer.to_string(temp)
    else
      if temp < 100 do
        " " <> Integer.to_string(temp)
      else
        Integer.to_string(temp)
      end
    end
  end
  def get_percent_helper(frames) do
    if(length(frames) < 1) do
      0
    else
      [head | tail] = frames
      {from, until} = head
      dur = until - from
      dur + get_percent_helper(tail)
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
      runningPairs = GenServer.call(
        pidNode,
        :retrieve_all_worker_pids
      )
      val = {head, pidNode, runningPairs}
      List.flatten([val,get_structured_list_of_nodes(tail)])
    end
  end
end
