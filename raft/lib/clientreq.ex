
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# Leader process client request, send entries to all followers
def receive_request_from_client(leader, m) do
  status = check_req_status(leader, m.cid)

  if status == :APPLIED_REQ do
    send m.clientP, { :CLIENT_REPLY, m.cid, m, leader.selfP }
    IO.puts("received applied request #{inspect m} from client, just reply.")
    leader
  end

  # IO.inspect(leader.log, label: "before received request from client. Leader log: ")
  leader = if status == :NEW_REQ do
    leader = Log.append_entry(leader, %{request: m, term: leader.curr_term})
    leader = State.commit_index(leader, Log.last_index(leader))                 # update the commit index for in the logs
    IO.inspect(leader.log, label: "line 22 Received request from client. Leader log:")
    leader
  else
    leader
  end
  # IO.inspect(leader.log, label: "line 14 Leader log: ")

  for n <- leader.servers do
    if n != leader.selfP && status == :NEW_REQ do
      AppendEntries.send_entries_to_followers(leader, n)
      leader
    else
      leader
    end # if
  end # for

  leader
end

def receive_reply_from_db(leader, db_seqnum, client_request) do
  leader = leader |> State.last_applied(db_seqnum)
  # IO.puts "db_seqnum: #{db_seqnum}"
  # IO.puts "leader last_applied after receive_reply_from_db #{leader.last_applied}"
  IO.puts "leader send client_request #{inspect(client_request.cid)} #{inspect(client_request)} to client #{}"
  send client_request.clientP, { :CLIENT_REPLY, client_request.cid, client_request, leader.selfP }

  for followerP <- leader.servers do
    send followerP, {:COMMIT_ENTRIES_REQUEST, db_seqnum}
  end

  leader
end

def check_req_status(leader, cid) do

  committedLog = Map.take(leader.log, Enum.to_list(1..leader.commit_index))
  committed_cid = for {k,v} <- committedLog, do: v.request.cid

  appliedLog = Map.take(leader.log, Enum.to_list(1..leader.last_applied))
  applied_cid = for {k,v} <- appliedLog, do: v.request.cid

  IO.puts("committed_cid: #{inspect(committed_cid)}, applied_cid: #{inspect(applied_cid)}")
  status = cond do
    # If log is empty, definitely a new request
    Log.last_index(leader) == 0 ->
      :NEW_REQ

    Enum.find(applied_cid, nil, fn entry -> entry == cid end) != nil ->
      :APPLIED_REQ

    Enum.find(committed_cid, nil, fn entry -> entry == cid end) != nil ->
      :COMMITTED_REQ

    true ->
      :NEW_REQ

    end
status # return
end

end # Clientreq
