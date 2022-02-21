# Alicia Law(ajl115) and Ye Liu(yl10321)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# Leader process client request, send entries to all followers
def receive_request_from_client(leader, m) do
  # Called when a client sends a :CLIENT_REQUEST to leader.
  # Inputs:
  #   - leader              : receipient of the client request
  #   - m                   : client request

  # (i) Check if cilent request has been processed by leader
  status = check_req_status(leader, m.cid)

  # (ii) If client request has already been applied to database, just send :CLIENT_REPLY to client
  if status == :APPLIED_REQ do
    send m.clientP, { :CLIENT_REPLY, m.cid, m, leader.selfP, leader.server_num }
    # IO.puts("received applied request #{inspect m} from client, just reply.")
    leader
  end

  # (ii) If client request has not been applied to database or appended to its log
  leader = if status == :NEW_REQ do
    leader = Log.append_entry(leader, %{request: m, term: leader.curr_term})    # append client request to leader's log
    leader = State.commit_index(leader, Log.last_index(leader))                 # update the commit index for in the logs
    # IO.inspect(leader.log, label: "Received request from client. Leader log")
    leader
  else
    leader
  end

  # (iii) If client request is a new request, send append entries request to other servers except itself
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
  # Called when a database sends a :CLIENT_REQUEST to leader.
  # Inputs:
  #   - leader              : receipient of the database reply
  #   - db_seqnum           : index of request in database
  #   - client_request      : client request

  # (i) Update leader's last_applied value
  leader = leader |> State.last_applied(db_seqnum)

  # (ii) Leader send reply to client that server has applied the request
  send client_request.clientP, { :CLIENT_REPLY, client_request.cid, client_request, leader.selfP, leader.server_num }

  # (iii) Leader broadcast to followers to commit the request to their local database
  for followerP <- leader.servers do
    send followerP, {:COMMIT_ENTRIES_REQUEST, db_seqnum}
  end
  leader
end

def check_req_status(leader, cid) do
  # Check client request status in servers
  # Inputs:
  #   - leader              : receipient of the client request
  #   - cid                 : unique id in client request

  # Requests and cids that have been appended to log but not applied to database
  committedLog = Map.take(leader.log, Enum.to_list(1..leader.commit_index))
  committed_cid = for {k,v} <- committedLog, do: v.request.cid

  # Requests and cids that have been applied to database
  appliedLog = Map.take(leader.log, Enum.to_list(1..leader.last_applied))
  applied_cid = for {k,v} <- appliedLog, do: v.request.cid

  status = cond do
    # If leader log is empty, it is a new request, return :NEW_REQ
    Log.last_index(leader) == 0 ->
      :NEW_REQ

    # If cid is in applied_cid, it has already been applied to database, return :APPLIED_REQ
    Enum.find(applied_cid, nil, fn entry -> entry == cid end) != nil ->
      :APPLIED_REQ

    # If cid is in committed_cid (but not in applied_cid), it has been appended to log, return :COMMITTED_REQ
    Enum.find(committed_cid, nil, fn entry -> entry == cid end) != nil ->
      :COMMITTED_REQ

    true ->
      :NEW_REQ
    end
status # return
end

end # Clientreq
