defmodule Assignment.HistoryKeeperSupervisor do

  use DynamicSupervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    children = [
      {Registry, keys: :unique, name: Assignment.History.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Assignment.HistoryKeeperWorkerSupervisor}
      # { Assignment.HistoryKeeperManager, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
