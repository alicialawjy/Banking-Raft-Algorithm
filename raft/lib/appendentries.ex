# Alicia Law(ajl115) and Ye Liu(yl10321)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do

# s = server process state (c.f. this/self)

  def send_entries_to_followers(leader, followerP) do
  # Called when a leader receives client request or append entries timeout
  # Inputs:
  #   - leader              : server who receives client request
  #   - followerP           : follower's process id

    # (i) If follower's next_index < leader's log length + 1, append new entries
    if leader.next_index[followerP] < (Log.last_index(leader) + 1) do

      followerPrevIndex = leader.next_index[followerP] - 1                              # follower's next_index - 1 (where to start the entry)
      entries = Log.get_entries(leader, (followerPrevIndex+1)..Log.last_index(leader))  # entries
      prevTerm = Log.term_at(leader, followerPrevIndex)                                 # term which followerPrevIndex is at

      # send append entries request to follower
      Timer.restart_append_entries_timer(leader,followerP)
      send followerP, { :APPEND_ENTRIES_REQUEST, leader.curr_term, followerPrevIndex, prevTerm, entries, leader.commit_index}
      leader

    # (ii) If follower is already up-to-date, leader sends dummy heartbeats to follower
    else
      Timer.restart_append_entries_timer(leader,followerP)
      send followerP, { :APPEND_ENTRIES_REQUEST, leader.curr_term, leader.commit_index }
      leader
    end
    leader
  end

  def receive_append_entries_request(s, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex) do
  # Called when a server receives leader's append entries request
  # Inputs:
  #   - s                   : leader who sends append entries request
  #   - leaderTerm          : leader's current term
  #   - prevIndex           : follower's next_index - 1
  #   - prevTerm            : term of follower's prevIndex
  #   - leaderEntries       : entries to append to follower's log
  #   - commitIndex         : leader's commit_index

    # (i) If I am a candidate/ leader but received an append entries request from someone with a larger term, stepdown:
    s = if s.role != :FOLLOWER && s.curr_term < leaderTerm do
      s = Vote.stepdown(s, leaderTerm)
    else
      s
    end #if

    # (ii) If my current term is larger than the leader's, reject leader
    if s.curr_term > leaderTerm do
      send s.leaderP, {:APPEND_ENTRIES_REPLY, s.selfP, s.curr_term, false, nil}
    end # if

    # (iii) If my current term == leader's term
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


  def storeEntries(s, prevIndex, entries, commitIndex) do
  # Called when a server receives leader's append entries request
  # Inputs:
  #   - s                   : leader who sends append entries request
  #   - prevIndex           : follower's next_index - 1
  #   - entries             : entries to append to follower's log
  #   - commitIndex         : leader's commit_index

    # (i) Find the point in the entry to start appending
    breakPointList = for {index, v} <- entries do
      if Log.last_index(s) >= index do
        if s.log[index].term != v.term do
          index
        else
          nil
        end
      else
        index
      end
    end

    breakPoint = Enum.min(breakPointList)                 # the index where the server's log and entries start to diverge

    # (ii) Delete extraneous entries
    entries = if breakPoint != nil do
      Map.drop(entries, Enum.to_list(0..(breakPoint-1)))  # delete the entries before breakPoint (which have been appended to follower's log)
    else
      %{}
    end

    s = if breakPoint != nil && breakPoint < Log.last_index(s) do
      s = s|>
      Log.delete_entries_from(breakPoint)               # delete entries from the point where diverge with leader
      s
    else
      s
    end

    # (iii) Merge logs from breakPoint onwards
    s = if entries != %{} do
      s = Log.merge_entries(s, entries)                 # append missing entries
      s = State.commit_index(s, Log.last_index(s))      # update commit index (for logs)
      s
    else
      s
    end
    s
  end

  def receive_append_entries_reply_from_follower(s, followerP, followerTerm, success, followerLastIndex) do
  # Called when a leader receives follower's reply for appending entries request
  # Inputs:
  #   - s                   : leader who sends append entries request
  #   - followerP           : follower's process id
  #   - followerTerm        : follower's current term
  #   - success             : check append entries consistency
  #   - followerLastIndex   : follower's log length

  # followerTerm here is definitely <= leader.curr_term

   # Update leader's next_index tracker with follower when consistency check success
   s = if success do
      s = State.next_index(s, followerP, followerLastIndex+1)
      s

  # Decrement follower's next_index when consistency check fails
   else
      s = State.next_index(s, followerP, max(s.next_index[followerP]-1, 1))
      send_entries_to_followers(s, followerP)
      s
   end

   # Check if majority of servers have committed request to log
   counter = for i <- (s.last_applied+1)..Log.last_index(s) // 1,
    into: Map.new
    do
    {i, Enum.reduce(s.servers, 1, fn followerP, count ->
      if followerP != s.selfP && s.next_index[followerP] > i do
        count + 1
      else
        count
      end
    end)}
   end

   for {index, c} <- counter do
    # If leader received majority reply from followers, notify the local database to store the request
    if c >= s.majority do
      send s.databaseP, {:DB_REQUEST, Log.request_at(s, index), index}
    else
      # IO.puts "do not commit request #{index}"
    end
   end
   s
  end

end # AppendEntriess
