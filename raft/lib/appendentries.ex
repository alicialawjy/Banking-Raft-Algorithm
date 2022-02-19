# Alicia Law() and Ye Liu(yl10321)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule AppendEntries do

# s = server process state (c.f. this/self)

  def send_entries_to_followers(leader, followerP) do
    if leader.next_index[followerP] < (Log.last_index(leader) + 1) do
      # IO.puts "CURRENT LOG LENGTH: #{map_size(leader.log)}"

      followerPrevIndex = leader.next_index[followerP] - 1                              # follower's the next_index (where to start the entry)
      entries = Log.get_entries(leader, (followerPrevIndex+1)..Log.last_index(leader))  # entries
      prevTerm = Log.term_at(leader, followerPrevIndex)

      # IO.puts("Line 24 - APPEND_ENTIRES_REQ contains following: followerPrevIndex: #{followerPrevIndex}, entries: #{inspect entries}, prevTerm: #{prevTerm} ")
      Timer.restart_append_entries_timer(leader,followerP)
      send followerP, { :APPEND_ENTRIES_REQUEST, leader.curr_term, followerPrevIndex, prevTerm, entries, leader.commit_index}
      # IO.inspect(leader, label: "leader #{leader.server_num} after sending entries to #{inspect(followerP)}")
      leader
    else # if follower is already up-to-date, just send heartbeats
      Timer.restart_append_entries_timer(leader,followerP)
      send followerP, { :APPEND_ENTRIES_REQUEST, leader.curr_term, leader.commit_index }
      # IO.puts("Followers are up-to-date. Sending heartbeats.")
      leader
    end
    leader
  end

  def receive_append_entries_request(s, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex) do
    # (i) If I am a candidate/ leader but received an append entries request from someone with a larger term, stepdown:
    s = if s.role != :FOLLOWER && s.curr_term < leaderTerm do
      IO.puts("Leader to stepdown as received aeReq from another leader of larger term - ae.ex Line 40")
      s = Vote.stepdown(s, leaderTerm)
    else
      s
    end #if

    # (ii) If my current term is larger than the leader's, reject leader
    if s.curr_term > leaderTerm do
      IO.puts("Server #{s.server_num} rejecting aeReq from leader bec have a larger term - ae.ex Line 46")
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
    # IO.inspect(s.log, label: "Server logs before storeEntries")
    IO.puts("storeEntries variables: prevIndex=#{prevIndex}, entries=#{inspect(entries)}, commitIndex=#{commitIndex}}")

    # find the point in the entry to start appending - min of breakpoint
    breakPointList = for {index, v} <- entries do
      # index = j
      if Log.last_index(s) >= index do
        IO.puts("index:#{index}, log length: #{Log.last_index(s)}, ")
        if s.log[index].term != v.term do
          index
        else
          nil
        end
      else
        index
      end
    end
    IO.puts("BreakpointLisr for Server #{s.server_num} = #{inspect breakPointList}")

    breakPoint = Enum.min(breakPointList)                 # the index where the server's log and entries start to diverge
    IO.puts("Append from entries index: #{breakPoint}")

    entries = if breakPoint != nil do
      Map.drop(entries, Enum.to_list(0..(breakPoint-1)))  # clear the entries before breakPoint
    else
      %{}
    end

    # delete logs if prevIndex is old
    s = if breakPoint != nil && breakPoint < Log.last_index(s) do
      s = s|>
      Log.delete_entries_from(breakPoint)    # Delete entries from the point where diverge with leader
      IO.inspect(s.log, label: "Server #{s.server_num}'s logs after delete_entries_from")
      s
    else
      s
    end

    # merge logs from breakPoint onwards
    s = if entries != %{} do
      s = Log.merge_entries(s, entries)                 # Append leader's entries
      s = State.commit_index(s, Log.last_index(s))      # Update commit index (for logs)
      IO.inspect(s.log, label: "Server #{s.server_num}'s logs after storeEntries - Line 114")
      IO.puts("Server #{s.server_num}'s commit index after storeEntries #{s.commit_index}")
      s
    else
      IO.puts("already updated. Server #{s.server_num}'s logs stay the same")
      s
    end
    s
  end

  def receive_append_entries_reply_from_follower(s, followerP, followerTerm, success, followerLastIndex) do
   # followerTerm here is definitely <= s.curr_term and s is a leader

   # Update leader's next_index tracker with follower
   s = if success do
      s = State.next_index(s, followerP, followerLastIndex+1)
      IO.puts("SUCCESSFUL aeReply - ae.ex Line 97. ")
      s
   else
      s = State.next_index(s, followerP, max(s.next_index[followerP]-1, 1))
      send_entries_to_followers(s, followerP)
      IO.puts("FAILED aeReply - ae.ex Line 97. ")
      s
   end
   IO.inspect(s.next_index, label: "next_index after aeReply Line 102")

   # Check if majority has committed to log

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

  #  IO.inspect(counter, label: "counter Line 155")
  #  IO.puts "s.log: #{inspect(s.log)} Line 156"

   for {index, c} <- counter do
    # IO.puts "checking count #{c} and majority #{s.majority}"
    if c >= s.majority do
      IO.puts "leader got majority reply, sending request #{index} to database"
      send s.databaseP, {:DB_REQUEST, Log.request_at(s, index), index} # send the database the request
    else
      IO.puts "do not commit request #{index}"
    end
   end

   s
  end

  # prevIndex = s.next_index[followerP]
  # send followerP, {:APPEND_ENTRIES_REQUEST, s.curr_term, prevIndex, Log.term_at(s, prevIndex), Log.get_entries(s,[(prevIndex+1)..Log.last_index(s)]), s.commit_index }

  #  if s.next_index[followerP] < Log.last_index(s) do
  #   send followerP {:APPEND_ENTRIES_REQUEST, Log.entry_at()}
  #   # request, prevIndex, prevTerm, leaderTerm, commitIndex
  #  end

# def send_entries_reply_to_leader(leader, isAppended)
# def receive_append_entries_reply_from_follower

end # AppendEntriess
