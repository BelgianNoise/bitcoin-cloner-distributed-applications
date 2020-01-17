  * [BONUS] You can update the timeframe of a specific coin.
* We're going to make our Logger a little bit more fancy:
  * When printing a message, we can give a "level" towards this message. This level indicates whether it is a debug message, information message, warning, etc... Use the levels mentioned [here](https://hexdocs.pm/logger/Logger.html).


  * [BONUS] `Assignment.HistoryKeeperWorker.update_timeframe(pid, %{from: _, until: _})` updates the new timeframe for that specific coin that it should clone. _Example usage: Assignment.HistoryKeeperManager.get_pid_for("USDT_BTC") |> Assignment.HistoryKeeperWorker.update_timeframe(%{from: 2_years_ago_in_unix, until: now_in_unix})_
  * `Assignment.HistoryKeeperManager.get_pid_for/1` returns the pid of the process that is keeping the history for that currency pair.
  * `Assignment.HistoryKeeperManager.retrieve_history_processes/0` returns a list of tuples. The first element of the tuple is a string (the currency pair) whereas the second element is the PID of the associated process.

* **_indicative_** tests -> check the file `assignment_two_test.exs`.

## Additional constraints

* We are changing the time frame from one week to 33 days. Test this with the sample config code.

