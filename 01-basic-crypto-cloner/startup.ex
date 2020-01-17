defmodule AssignmentOne.Startup do
  require IEx

  # This is just here to help you.
  # If you prefer another implementation, go ahead and change this (with the according startup callback)
  @from (DateTime.utc_now() |> DateTime.to_unix()) - 60 * 60 * 24 * 7
  @until DateTime.utc_now() |> DateTime.to_unix()

  defstruct from: @from, until: @until, req_per_sec: 5

  def start_link(args \\ []),
    do: {:ok, spawn_link(__MODULE__, :startup, [struct(__MODULE__, args)])}

  def startup(%__MODULE__{} = info) do
    AssignmentOne.Logger.start_link()
    AssignmentOne.ProcessManager.start_link()
    AssignmentOne.RateLimiter.start_link(info.req_per_sec)

    pairs = retrieve_coin_pairs()
    start_processes(pairs, info.from, info.until)

    keep_running_until_stopped()
  end

  defp retrieve_coin_pairs() do
    url = "https://poloniex.com/public?command=returnTicker"
    {:ok, response} = Tesla.get(url)
    decodedeBody = response.body|>Jason.decode!()
    _coinPairs = decodedeBody|>Enum.map(fn {
      key, _value
    } -> key end)
  end

  def start_processes(pairs, from, until) when is_list(pairs) do
    Enum.each(pairs, fn x -> create_proc(x, from, until) end)
  end
  defp create_proc(pair, from, until) do
    {:ok, pid} = AssignmentOne.CoindataRetriever.start({pair, from, until})
    AssignmentOne.ProcessManager.add_entry(pair, pid)
  end
  defp keep_running_until_stopped() do
    receive do
      :stop -> Process.exit(self(), :normal)
    end
  end
end
