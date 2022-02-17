
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# Leader process client request, send entries to all followers
def receive_request_from_client(leader, m) do
  #
  leader = leader
    |> Log.append_entry(%{request: m, term: leader.curr_term})   # append the new client request
    |> State.commit_index(Log.last_index(leader))                         # update the commit index for in the logs

  for n <- leader.servers do
    if n != leader.selfP do
      AppendEntries.send_entries_to_followers(leader, n)

      # lastLogIndex = min(State.get_next_index(leader, n), State.get_log_length(leader))
      # leader = leader |> State.last_log_index(lastLogIndex)
      #                 |> State.next_index(n, lastLogIndex)
      # send n, { :APPEND_ENTRIES_REQUEST, Log.get_entries(lastLogIndex, State.get_log_length(leader)), lastLogIndex-1, Log.term_at(leader, lastLogIndex-1), leader.curr_term, leader.commit_index}
      leader
    else
      leader
    end # if
  end # for
  IO.inspect(leader.log, label: "Received request from client. Leader log: ")
  leader
end

end # Clientreq
