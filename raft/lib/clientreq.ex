
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# Leader process client request, send entries to all followers
def receive_request_from_client(leader, m) do
  # IO.inspect(leader, label: "before appending client request to leader log")
  leader = Log.append_entry(leader, {:cmd, m.cmd, :term, leader.curr_term})
  # IO.inspect(leader, label: "after appending client request to leader log")

  for n <- leader.servers do
    if n != leader.selfP do
      # lastLogIndex = min(State.get_next_index(leader, n), State.get_log_length(leader))
      # leader = leader |> State.last_log_index(lastLogIndex)
      #                 |> State.next_index(n, lastLogIndex)
      # send n, { :APPEND_ENTRIES_REQUEST, Log.get_entries(lastLogIndex, State.get_log_length(leader)), lastLogIndex-1, Log.term_at(leader, lastLogIndex-1), leader.curr_term, leader.commit_index}
      AppendEntries.send_entries_to_followers(leader, n)
    end
    leader
  end
  IO.inspect(leader, label: "leader after receive_request_from_client")
  leader
end

end # Clientreq
