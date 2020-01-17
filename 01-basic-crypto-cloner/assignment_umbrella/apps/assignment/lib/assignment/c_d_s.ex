defmodule Assignment.CoindataSupervisor do

  use Supervisor

  def start_link(_g) do
    Supervisor.start_link(__MODULE__,nil, name: __MODULE__)
  end

  def init(_g) do
   children = [
    {Registry, keys: :unique, name: Assignment.Coindata.Registry},
    {DynamicSupervisor, strategy: :one_for_one, name: Assignment.CoindataRetrieverSupervisor}
     # {Assignment.ProcessManager, []}
   ]

   Supervisor.init(children, strategy: :one_for_one)
  end
end
