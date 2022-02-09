
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Client do

# c = client process state (c.f. self/this)

# _________________________________________________________ Client setters()
def seqnum(c, v),  do: Map.put(c, :seqnum, v)
def request(c, v), do: Map.put(c, :request, v)
def result(c, v),  do: Map.put(c, :result, v)
def leaderP(c, v), do: Map.put(c, :leaderP, v)
def servers(c, v), do: Map.put(c, :servers, v)

# _________________________________________________________ Client.start()
def start(config, client_num, servers) do
  config = config
    |> Configuration.node_info("Client", client_num)
    |> Debug.node_starting()

  Process.send_after(self(), :CLIENT_TIMELIMIT, config.client_timelimit)

  c = %{                              # initialise client state variables
    config:     config,
    client_num: client_num,
    clientP:    self(),
    servers:    servers,
    leaderP:    nil,
    seqnum:     0,
    request:    nil,
    result:     nil,
  }

  c |> Client.next()
end # start

# _________________________________________________________ Client.next()
def next(c) do
  if c.seqnum == c.config.max_client_requests do          # all done
    Helper.node_sleep("Client #{c.client_num} all requests completed = #{c.seqnum}")
  end # if

  receive do
  { :CLIENT_TIMELIMIT } ->
    Helper.node_sleep("  Client #{c.client_num}, client timelimit reached, tent = #{c.seqnum}")

  after c.config.client_request_interval ->

    account1 = Enum.random 1 .. c.config.n_accounts         # from account
    account2 = Enum.random 1 .. c.config.n_accounts         # to account
    amount   = Enum.random 1 .. c.config.max_amount

    c   = Client.seqnum(c, c.seqnum + 1)
    cmd = { :MOVE, amount, account1, account2 }
    cid = { c.client_num, c.seqnum }                        # unique client id for cmd

    c = c
      |> Client.request({ :CLIENT_REQUEST, %{clientP: c.clientP, cid: cid, cmd: cmd } })
      |> Client.send_client_request_receive_reply(cid)   

    Client.next(c)
  end # receive
end # next

# _________________________________________________________ send_client_request_receive_reply()
def send_client_request_receive_reply(c, cid) do
  c |> Client.send_client_request_to_leader()
    |> Client.receive_reply_from_leader(cid)
end # send_client_request_receive_reply

# _________________________________________________________ send_client_request_to_leader()
def send_client_request_to_leader(c) do
  c = if c.leaderP do c else  # round-robin leader selection
    [server | rest] = c.servers
    c = c |> Client.leaderP(server) 
          |> Client.servers(rest ++ [server])
    c
  end # if
  send c.leaderP, c.request
  c
end # send_client_request_to_leader

# _________________________________________________________ receive_reply_from_leader()
def receive_reply_from_leader(c, cid) do
  receive do
  { :CLIENT_REPLY, m_cid, :NOT_LEADER, leaderP } when m_cid == cid ->
    Process.sleep(200)
    c |> Client.leaderP(leaderP)     
      |> Client.send_client_request_receive_reply(cid)

  { :CLIENT_REPLY, m_cid, reply, leaderP } when m_cid == cid ->
    c |> Client.result(reply)
      |> Client.leaderP(leaderP)     

  { :CLIENT_REPLY, m_cid, _reply, _leaderP } when m_cid < cid -> 
    c |> Client.receive_reply_from_leader(cid)

  { :CLIENT_TIMELIMIT } ->
    Helper.node_sleep("  Client #{c.client_num}, client timelimit reached, sent = #{c.seqnum}")

  unexpected ->
    Helper.node_halt("***************** Client: unexpected message #{inspect unexpected}")

  after c.config.client_reply_timeout ->
       
    # leader probably crashed, retry with next server
    c |> Client.leaderP(nil)
      |> Client.send_client_request_receive_reply(cid)
  end # receive
end # receive_reply

end # Client

