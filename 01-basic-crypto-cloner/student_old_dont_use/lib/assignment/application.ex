defmodule Assignment.Application do
  use Application

  def start(_type, _args) do
    topologies = [
      da_assignment_test: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts:
        [:node1@localhost, :node2@localhost, :node3@localhost]],
        connect: {:net_kernel, :connect_node, []},
        list_nodes: {:erlang, :nodes, [:connected]}
      ]
    ]
    children = [
      {Cluster.Supervisor,
        [topologies, [name: Assignment.ClusterSupervisor]]},
      {Assignment.Logger,[]},
      {Assignment.RateLimiter, []},
      {Assignment.CoindataCoordinator, []},
      {Assignment.CoindataSupervisor,[]},
      {Assignment.HistoryKeeperSupervisor,[]}
    ]

    opts = [strategy: :one_for_one, name: Assignment.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
