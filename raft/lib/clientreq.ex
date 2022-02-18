
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# Leader process client request, send entries to all followers
def receive_request_from_client(leader, m) do
  # IO.inspect(leader.log, label: "before received request from client. Leader log: ")
  leader = Log.append_entry(leader, %{request: m, term: leader.curr_term})
  leader = State.commit_index(leader, Log.last_index(leader))                             # update the commit index for in the logs
  # IO.inspect(leader.log, label: "line 14 Leader log: ")

  for n <- leader.servers do
    if n != leader.selfP do
      AppendEntries.send_entries_to_followers(leader, n)
      leader
    else
      leader
    end # if
  end # for
  IO.inspect(leader.log, label: "line 24 Received request from client. Leader log: ")
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

end # Clientreq
