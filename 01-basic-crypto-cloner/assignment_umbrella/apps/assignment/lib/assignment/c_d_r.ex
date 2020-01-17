defmodule Assignment.CoindataRetriever do
  use GenServer

  defstruct [ pair: "", history: [] ]

  def start_link(args) do
    pair = args[:pair] ||
      raise "Created a CoindataRetriever worker without pair information!"
    GenServer.start_link(__MODULE__, args,
    name: {:via, Registry, {Assignment.Coindata.Registry, pair}})
  end

  def init(pairr) do
    state = struct(__MODULE__, pair: pairr)
    {:ok, state, {:continue, :verderdoen}}
  end

  def handle_continue(:verderdoen, state) do
    Assignment.Logger.log(:debug, "Created Retriever #{inspect state.pair}")
    :timer.sleep(400)
    send(self(), :ask_permission)
    {:noreply, state}
  end

  def stop(pair) do
    GenServer.stop(via_tuple(pair), :normal)
  end

  def via_tuple(pid) when is_pid(pid) do
    pid
  end

  def via_tuple(name) do
    {:via, Registry, {Assignment.Coindata.Registry, name}}
  end

  def start_multiple(pid) do
    send(pid, :ask_permission)
  end

  def handle_info(:ask_permission, state) do
    Assignment.RateLimiter.request_permission(self())
    {:noreply, state}
  end

  def handle_info(:go, state) do
    res = Assignment.HistoryKeeperWorker.request_timeframe(state.pair)
    if res != nil do
      {sta, en} = res
      start = trunc(sta)
      endd = trunc(en)
      prpr = List.keyfind(state.pair, :pair, 0)|>elem(1)
      url = "https://poloniex.com/public?command=returnTradeHistory&currencyPair=#{prpr}&start=#{start}&end=#{endd}"
      {:ok, response} = Tesla.get(url)
      decodedBody = response.body|>Jason.decode!()
      if (length(decodedBody) > 999) do
        # vragen voor te splitten
        Assignment.HistoryKeeperWorker.splitFrame(state.pair, start, endd)
        # 2 keer permission voor frames
        send(self(), :ask_permission)
        {:noreply, state}
      else
        new_state = %{state | history: List.flatten(state.history ++ [decodedBody])}
        # {_, s} = DateTime.from_unix(start)
        # {_, e} = DateTime.from_unix(endd)
        # Assignment.Logger.log(:info, "#{inspect self()} - #{inspect state.pair} - Retrieved data(#{inspect length(decodedBody)}): #{inspect s} t.e.m. #{inspect e}")
        # ff de data doorsture dan zeker
        Assignment.HistoryKeeperWorker.receive_history(state.pair, [decodedBody])
        send(self(), :ask_permission)
        {:noreply, new_state}
      end
    else
      # Assignment.Logger.log(:info, "No more timeframes for: #{inspect state.pair}")
      {:noreply, state}
    end
  end

  def handle_call(:get_history, _sender, state) do
    {:reply, {state.pair, state.history}, state}
  end

  def handle_call(:get_pair, _, state) do
    {:reply, state.pair, state}
  end
  def get_history(worker_pid) when is_pid(worker_pid) do
    GenServer.call(worker_pid, :get_history)
  end

  def get_pair_for(pid) do
    GenServer.call(pid, :get_pair)
  end
end
