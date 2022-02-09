
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Raft do

# _________________________________________________________ Raft.start/0
def start do
  config = Configuration.node_init()
  Raft.start(config, config.start_function)
end # start/0

# _________________________________________________________ Raft.start/2
def start(_config, :cluster_wait), do: :skip
def start(config,  :cluster_start) do
  # more initialisations
  config = config
    |> Configuration.node_info("Raft")
    |> Map.put(:monitorP, spawn(Monitor, :start, [config]))

  # create 1 database and 1 raft server in each server-node
  servers = for num <- 1 .. config.n_servers do
    Node.spawn(:'server#{num}_#{config.node_suffix}', Server, :start, [config, num])
  end # for

  databases = for num <- 1 .. config.n_servers do
    Node.spawn(:'server#{num}_#{config.node_suffix}', Database, :start, [config, num])
  end # for

  # bind servers and databases
  for num <- 0 .. config.n_servers-1 do
    serverP   = Enum.at(servers, num) 
    databaseP = Enum.at(databases, num)
    send serverP,   { :BIND, servers, databaseP }
    send databaseP, { :BIND, serverP }
  end # for 

  # create 1 client in each client_node and bind to servers
  for num <- 1 .. config.n_clients do
    Node.spawn(:'client#{num}_#{config.node_suffix}', Client, :start, [config, num, servers])
  end # for

end # start

end # Raft
