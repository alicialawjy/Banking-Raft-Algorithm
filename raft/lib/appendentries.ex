
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do

# s = server process state (c.f. this/self)


  def receive_append_entries_request(s, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex) do
    # (i) If I am a candidate/ leader but received an append entries request from someone with a larger term, stepdown:
    s = if s.role != :FOLLOWER && s.curr_term < leaderTerm do
      s = Vote.stepdown(s, leaderTerm)
    end #if

    # (ii) If my current term is larger than the leader's, reject leader
    if s.curr_term > leaderTerm do
      send s.leaderP, {:APPEND_ENTRIES_REPLY, s.selfP, s.curr_term, false, nil}
    end # if

    # (iii) If my current term == leader's
    # Check if can successfully append: i.e. if our prev index and terms match too
    success = (s.curr_term == leaderTerm) && (prevIndex == 0 || (prevIndex <= Log.last_index(s) && prevTerm == Log.term_at(s, prevIndex)))

    s =
      if success do
        s = storeEntries(s, prevIndex, leaderEntries, commitIndex)
      else
        s
      end # if

    if s.curr_term == leaderTerm do
      send s.leaderP, {:APPEND_ENTRIES_REPLY, s.selfP, s.curr_term, success, s.commit_index}
    end

    s
  end # receive_append_entries_request

  # def storeEntries(s, prevIndex, entries, commitIndex) do
  #   index = prevIndex
  #   for j <- 1..map_size(request) do
  #     index = index + 1
  #     if Log.term_at(s, index) != Log.term_at(s, request[j]) do
  #       Log.append_entries(s, request[j])
  #     end
  #   end
  #   commitIndex = min(commitIndex, index)
  #   index
  # end

  def storeEntries(s, prevIndex, entries, commitIndex) do
    s = s
      |> Log.delete_entries_from(s, prevIndex)            # Delete entries from the point where diverge with leader
      |> Log.merge_entries(entries)                       # Append leader's entries
      |> State.commit_index(Log.last_index(s))    # Update commit index (for logs)
  end

  def receive_append_entries_reply_from_follower(s, followerP, followerTerm, success, followerLastIndex) do
   # followerTerm here is definitely <= s.curr_term and s is a leader

   # Update leader's next_index tracker with follower
   s = if success do
      s = State.next_index(s, followerP, followerLastIndex+1)
   else
      s = State.next_index(s, followerP, max(s.next_index[followerP]-1, 1))
   end

   prevIndex = s.next_index[followerP]
   send followerP, {:APPEND_ENTRIES_REQUEST, s.curr_term, prevIndex, Log.term_at(s, prevIndex), Log.get_entries(s,[(prevIndex+1)..Log.last_index(s)]), s.commit_index }

   s
  end

  def receive_append_entries_timeout(leader, followerP) do
    send followerP, {:APPEND_ENTRIES_REQ, leader.curr_term, leader.commit_index } # send heartbeat
  end

# def send_entries_reply_to_leader(leader, isAppended)
 # def receive_append_entries_reply_from_follower

end # AppendEntriess
