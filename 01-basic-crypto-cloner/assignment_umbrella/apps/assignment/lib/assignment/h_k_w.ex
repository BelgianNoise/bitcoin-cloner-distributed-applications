defmodule Assignment.HistoryKeeperWorker do

  use GenServer

  defstruct [pair: nil, history: [],
  frames: [{Application.get_env(:assignment, :from),
            Application.get_env(:assignment, :until)}] ]

  def start_link(args) do
    pair = args[:pair] ||
      raise "Created a CoindataRetriever worker without pair information!"
    GenServer.start_link(__MODULE__, args,
    name: {:via, Registry, {Assignment.History.Registry, pair}})
  end

  def init(args) do
    state = struct(__MODULE__, args)
    if has_over_one_month(state.frames) do
      #do stuffs
      {start, endd} = List.first(state.frames)
      #uitreken hoeveel maanden we coveren
      divide_in_n_frames = ceil((endd - start) / (24*60*60*30))
      #breedte van elke nieuwe frame
      width = ceil((endd - start) / divide_in_n_frames)
      # de frames lekker snijden
      new_frames = cut_frames(start, divide_in_n_frames, width)
      new_state = %{state | frames: new_frames}
      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  def get_coin_pid(pair) when is_list(pair) do
    list = Assignment.CoindataCoordinator.retrieve_all_registry_workerkeys()
    pair = List.keyfind(pair, :pair, 0)|>elem(1)
    pid = list |> Enum.into(%{}) |> Map.fetch!(pair)
    pid
  end
  def get_coin_pid(pair) do
    list = Assignment.CoindataCoordinator.retrieve_all_registry_workerkeys()
    pid = list |> Enum.into(%{}) |> Map.fetch!(pair)
    pid
  end

  def handle_info(:fix_frames, state) do
    #als de frame langer is dan 30 dage moet die in 2 eh
    if has_over_one_month(state.frames) do
      #do stuffs
      {start, endd} = List.first(state.frames)
      #uitreken hoeveel maanden we coveren
      divide_in_n_frames = ceil((endd - start) / (24*60*60*30))
      #breedte van elke nieuwe frame
      width = ceil((endd - start) / divide_in_n_frames)
      # de frames lekker snijden
      new_frames = cut_frames(start, divide_in_n_frames, width)
      new_state = %{state | frames: new_frames}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  defp cut_frames(start, aantalkeer, width) do
    if aantalkeer < 1 do
      []
    else
      List.flatten(
        [  {floor(start + ((aantalkeer-1) * width)),
                 ceil(start + (aantalkeer * width))} ] ++
        cut_frames(start, aantalkeer-1, width)
        )
    end
  end
  defp has_over_one_month(frames) do
    Enum.any?(frames, fn {start, endd} ->
      endd - start >= 24*60*60*30
    end)
  end
  def handle_call(:history, _from, state) do
    {:reply, {state.pair, state.history}, state}
  end

  def handle_call(:info, _from ,state) do
    {:reply, state.pair, state}
  end

  def handle_call(:request_time, _from ,state) do
    new_state = %{state | frames: List.delete_at(state.frames, 0)}
    {:reply, List.first(state.frames), new_state}
  end
  def handle_call(:get_frames, _from, state) do
    {:reply, state.frames, state}
  end
  def get_frames(pid) do
    GenServer.call(pid, :get_frames)
  end
  def get_history(pid) do
    GenServer.call(pid, :history)
  end

  def get_pair_info(pid) do
    GenServer.call(pid, :info)
  end

  def request_timeframe(pair) do
    pid = get_coin_pid(pair)
    GenServer.call(pid, :request_time)
  end

  def splitFrame(pair, start, endd) do
    pid = get_coin_pid(pair)
    GenServer.cast(pid, {:split, start, endd})
  end
  def receive_history(pair, hist) do
    pid = get_coin_pid(pair)
    GenServer.cast(pid, {:add_hist, hist})
  end
  def set_history(pair, hist) do
    pid = get_coin_pid(pair)
    GenServer.cast(pid, {:set_history, hist})
  end
  def set_frames(pair, frames) do
    pid = get_coin_pid(pair)
    GenServer.cast(pid, {:set_frames, frames})
  end

  def handle_cast({:set_frames, fra}, state) do
    new_state = %{state | frames: fra}
    {:noreply, new_state}
  end
  def handle_cast({:set_history, hist}, state) do
    new_state = %{state | history: hist}
    {:noreply, new_state}
  end
  def handle_cast({:add_hist, hist}, state) do
    new_state = %{state | history: List.flatten(state.history ++ [hist])}
    {:noreply, new_state}
  end
  def handle_cast({:split, start, endd}, state) do
    # Assignment.Logger.log(:info, "Split Frame : #{inspect start} - #{inspect endd}")
    # 2 nieuwe frames maken
    diff = endd - start
    second_start = trunc(start + (diff/2))
    new_frames = state.frames ++ [{start, second_start}] ++ [{second_start, endd}]
    new_state = %{state | frames: new_frames}
    {:noreply, new_state}
  end

  def stop(pair) do
    GenServer.stop(via_tuple(pair), :normal)
  end

  def via_tuple(pid) when is_pid(pid) do
    pid
  end

  def via_tuple(name) do
    {:via, Registry, {Assignment.History.Registry, name}}
  end
end
