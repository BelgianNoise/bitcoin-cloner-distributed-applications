defmodule Reporter.Application do
  use Application

  def start(_type, _args) do
    topologies = [
      da_assignment_reporter: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts:
        [:reporter@localhost, :node1@localhost,
          :node2@localhost, :node3@localhost]],
        connect: {:net_kernel, :connect_node, []},
        list_nodes: {:erlang, :nodes, [:connected]}
      ]
    ]
    children = [
      {Cluster.Supervisor,
        [topologies, [name: Reporter.ClusterSupervisor]]},
      {Reporter.Reporter,[]}
    ]

    opts = [strategy: :one_for_one, name: Reporter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
