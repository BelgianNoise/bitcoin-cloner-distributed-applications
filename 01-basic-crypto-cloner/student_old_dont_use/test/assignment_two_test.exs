defmodule AssignmentTest do
  use ExUnit.Case

  alias Assignment.{
    Logger,
    CoindataRetrieverSupervisor,
    RateLimiter,
    ProcessManager,
    HistoryKeeperManager,
    HistoryKeeperWorkerSupervisor,
    HistoryKeeperWorker
  }

  test "Processes are registered" do
    # Should always pass
    [
      Logger,
      CoindataRetrieverSupervisor,
      RateLimiter,
      ProcessManager,
      HistoryKeeperManager,
      HistoryKeeperWorkerSupervisor
    ]
    |> Enum.all?(fn pid -> Process.whereis(pid) |> Process.alive?() end)
  end

  test "ProcessManager returns list of currency pairs" do
    # Should always pass. Timer should no longer be necessary
    # Note: This is an indicative test. Verify the # of currency pairs yourself
    :timer.sleep(500)
    procs = ProcessManager.retrieve_coin_processes()
    assert Enum.all?(procs, &is_tuple/1)
    assert Enum.all?(procs, fn {bin, pid} -> is_binary(bin) and is_pid(pid) end)
    assert length(procs) > 80
  end

  test "Logger can print with different levels" do
    Logger.log(:warn, "THIS IS A WARNING")
    Logger.log(:info, "THIS IS INFO")
    Logger.log(:debug, "THIS IS DEBUG")
    # Verify manually
    assert true
  end

  test "Processmanager its output is good and unique" do
    list = ProcessManager.retrieve_coin_processes()
    assert all_processes_in_processmanager_good?(list)
  end

  test "Processmanager processes gets restarted. ProcessManager has no invalid state." do
    # Normally this should pass 95% of the time. If not, there's most likely something wrong.
    # FYI: Yes I'm using tests like these to do the evaluation.
    list = ProcessManager.retrieve_coin_processes()
    l1 = length(list)
    list |> Enum.random() |> elem(1) |> Process.exit(:kill)
    l2 = length(list)
    list |> Enum.random() |> elem(1) |> Process.exit(:kill)
    l3 = length(list)
    list |> Enum.random() |> elem(1) |> Process.exit(:kill)
    l4 = length(list)
    Process.whereis(ProcessManager) |> Process.exit(:kill)
    :timer.sleep(500)
    list = ProcessManager.retrieve_coin_processes()
    l5 = length(list)

    assert all_processes_in_processmanager_good?(list)
    assert l1 == l2
    assert l2 == l3
    assert l3 == l4
    assert l4 == l5
  end

  test "History workers have correct output" do
    list = HistoryKeeperManager.retrieve_history_processes()

    assert Enum.all?(list, fn {k, p} ->
             case HistoryKeeperWorker.get_history(p) |> Tuple.to_list() |> length do
               2 ->
                 {resp_k, resp_h} = HistoryKeeperWorker.get_history(p)

                 if resp_k != k do
                   raise "registered key value in process manager doesn't match with worker response"
                 end

                 Enum.all?(resp_h, &is_map/1)

               _ ->
                 Logger.warn("History not in tuple or name not in tuple?")
                 false
             end
           end)

    # If you want to verify manually :
    # list = HistoryKeeperManager.retrieve_history_processes()
    # {_, p} = Enum.filter(list, fn {k, p} -> k == "USDC_BTC" end) |> List.first()
    # {_, h} = HistoryKeeperWorker.get_history(p)
    # length(h)
  end

  defp all_processes_in_processmanager_good?(list) do
    check1 = Enum.all?(list, &is_tuple/1)

    # All processes / pairs are unique
    check2 =
      Enum.all?(list, fn {k, v} ->
        length(Enum.filter(list, fn {other_k, other_v} -> other_k == k or other_v == v end)) == 1
      end)

    # All processes are alive
    check3 = Enum.all?(list, fn {_k, v} -> Process.alive?(v) end)
    check1 and check2 and check3
  end

  # Manual tests
  # First test is to adjust config values to 33 days
  # If this doesn't crash your application, reset it to 12 hrs and see if your application actually stops.
  # Open observer.start, go to the applications tab and kill random processes (behind your application supervisor)
end
