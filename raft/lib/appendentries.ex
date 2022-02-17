
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do

# s = server process state (c.f. this/self)

  # def send_entries_to_followers(leader, followerP, client_msg) do
  #   send followerP, { :APPEND_ENTRIES_REQUEST, client_msg, Log.last_index(leader)-1, term_at(leader, Log.last_index(leader)-1), leader.curr_term, leader.commit_index}
  # end

  def send_entries_to_followers(leader, followerP) do
    if map_size(leader.log) != 0 do
      IO.puts "CURRENT LOG LENGTH: #{map_size(leader.log)}"
      lastLogIndex = min(State.get_next_index(leader, followerP), map_size(leader.log))
      IO.puts "lastLogIndex-1: #{lastLogIndex-1}, logLength: #{map_size(leader.log)}"
      leader = leader |> State.last_log_index(lastLogIndex)
                      |> State.next_index(followerP, lastLogIndex)
      send followerP, { :APPEND_ENTRIES_REQUEST, Log.get_entries(leader, lastLogIndex..map_size(leader.log)), lastLogIndex-1, Log.term_at(leader, lastLogIndex-1), leader.curr_term, leader.commit_index}
      leader
    else
      leader
    end
    IO.inspect(leader, label: "leader after sending entries")
    leader
    # send followerP, { :APPEND_ENTRIES_REQUEST, client_msg, Log.last_index(leader)-1, term_at(leader, Log.last_index(leader)-1), leader.curr_term, leader.commit_index}
  end


  def receive_append_entries_request(s, request, prevIndex, prevTerm, leaderTerm, commitIndex) do
    # If I am a candidate/ leader but received an append entries request from some leader greater than me, STEPDOWN
    s = if s.role != :FOLLOWER && s.curr_term < leaderTerm do
      s = Vote.stepdown(s, leaderTerm)
    end #if

    if s.curr_term > leaderTerm do
      send s.leaderP, {:APPEND_ENTRIES_REPLY, s.selfP, s.curr_term, false, nil}
    end # if

    success = (s.curr_term == leaderTerm) && (prevIndex == 0 || (prevIndex <= Log.last_index(s) && prevTerm == Log.term_at(s, prevIndex)))

    s =
      if success do
        s = storeEntries(s, prevIndex, request,commitIndex)
        # Log.append_entry(s,request)
        send s.leaderP, {:APPEND_ENTRIES_REPLY, s.selfP, s.curr_term, success, map_size(s.log)}
      else
        s
      end # if
    s
  end # receive_append_entries_request

  def storeEntries(s, prevIndex, request, commitIndex) do
    s = s
      |> Log.delete_entries_from(prevIndex)
      |> Log.merge_entries(request)
      |> State.commit_index(min(commitIndex, map_size(s.log)))
    IO.inspect(s, label: "follower after storeEntries")
    s
    # index = prevIndex
    # for j <- 1..map_size(request) do
    #   index = index + 1
    #   if Log.term_at(s, index) != Log.term_at(s, request[j]) do
    #     Log.append_entries(s, request[j])
    #   end
    # end
    # commitIndex = min(commitIndex, index)
    # index
  end


  def receive_append_entries_reply_from_follower(s, followerP, followerTerm, success, followerLastIndex) do
   # followerTerm here is definitely == s.curr_term
   s = if success do
      s = State.next_index(s, followerP, followerLastIndex+1)
   else
      s = State.next_index(s, followerP, max(s.next_index[followerP]-1, 1))
   end

  #  if s.next_index[followerP] < Log.last_index(s) do
  #   send followerP {:APPEND_ENTRIES_REQUEST, Log.entry_at()}
  #   # request, prevIndex, prevTerm, leaderTerm, commitIndex
  #  end

  end


  def receive_append_entries_timeout(leader, followerP) do
    send_entries_to_followers(leader, followerP)
  end


# def send_entries_reply_to_leader(leader, isAppended)
 # def receive_append_entries_reply_from_follower

end # AppendEntriess
