
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule ClientReq do

# s = server process state (c.f. self/this)

# Leader process client request, send entries to all followers
def receive_request_from_client(leader, m) do
  #
  leader = Log.append_entry(leader, {:request, m, :term, leader.curr_term})
  for n <- leader.servers do
    if n != leader.selfP do
      send n, { :APPEND_ENTRIES_REQUEST, Log.get_entries(Log.last_index(leader), Log.last_index(leader)), Log.last_index(leader)-1, term_at(leader, Log.last_index(leader)-1), leader.curr_term, leader.commit_index}

      # AppendEntries.send_entries_to_followers(leader, n, m)
  end
end

end

end # Clientreq
