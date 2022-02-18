
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Server do

# s = server process state (c.f. self/this)

# _________________________________________________________ Server.start()
def start(config, server_num) do
  config = config
    |> Configuration.node_info("Server", server_num)
    |> Debug.node_starting()
  IO.puts "server #{server_num} starts"

  receive do
  { :BIND, servers, databaseP } ->
    s = State.initialise(config, server_num, servers, databaseP) # server_num: own number, servers: all the servers, databaseP: the system db
    # IO.inspect(s, label: "before timer")
    s |> Timer.restart_election_timer()
      |> Server.next()
  end # receive
end # start

# _________________________________________________________ next()
def next(s) do
  # s = s |> Server.execute_committed_entries()
  # IO.inspect(s, label: "At the start of next()")
  curr_term = s.curr_term                          # used to discard old messages
  # curr_election = s.curr_election                  # used to discard old election timeouts

  s = receive do

  # ---------------- VOTE-RELATED MESSAGES ------------------
  # (i) When election timer runs out
  # From: Self {Follower, Candidate} >> To: Self
  # If
  { :ELECTION_TIMEOUT, mterm, melection } = msg when mterm < curr_term ->
    IO.puts("Server #{s.server_num} received old election timeout. mterm = #{mterm} curr_term = #{curr_term}")
    # s |> Debug.received("Server #{s.server_num} received old election timeout. mterm = #{mterm} curr_term = #{curr_term}")
    s

  { :ELECTION_TIMEOUT, mterm, melection } = msg when (s.role != :LEADER) -> # equal or larger than curr_term
    IO.puts("Server #{s.server_num} Election Timeout - START")
    s = s
      |> Debug.received("-etim", msg)
      |> Vote.receive_election_timeout()

    # IO.inspect(s, label: "s after election timeout finished - in server.ex")
    s
  # ________________________________________________________
  # (ii) When follower received vote request from candidate
  # If candidate term is lower, do not vote
  { :VOTE_REQUEST, [candidate_curr_term, candidate_num, _candidate_id, candidateLastLogTerm, candidateLastLogIndex] } when candidate_curr_term < curr_term ->
    IO.puts("Server #{s.server_num} received vote req from Server #{candidate_num} but did not vote")
    s

  # If candidate term >= ours, process:
  { :VOTE_REQUEST, [candidate_curr_term, candidate_num, candidate_id, candidateLastLogTerm, candidateLastLogIndex] } = msg ->
    s = s
      |> Debug.message("-vreq", msg)
      |> Vote.receive_vote_request_from_candidate(candidate_curr_term, candidate_num, candidate_id, candidateLastLogTerm, candidateLastLogIndex)

    # IO.inspect(s, label: "s #{s.server_num} after receive_vote_request_from_candidate #{candidate_num} finished - in server.ex")
    s
  # ________________________________________________________
  # (iii) When candidate received a vote reply from a follower
  # follower_curr_term: the election term that the follower voted in.

  # If the vote reply was for an old election, discard:
  { :VOTE_REPLY, follower_num, follower_curr_term } when follower_curr_term < curr_term ->
    IO.puts("Outdated Vote Reply from Server #{follower_num} to Server #{s.server_num}")
    # Debug.received("Discard Reply to old Vote Request #{inspect msg}")
    s

  # If the server is still a candidate and vote reply is for this term's election, accept:
  { :VOTE_REPLY, follower_num, follower_curr_term } = msg when s.role == :CANDIDATE -> #when follower_curr_term == curr_term
    s = s
      |> Debug.message("-vrep", msg)
      |> Vote.receive_vote_reply_from_follower(follower_num, follower_curr_term)
    s
  # If server steped down/ is already a leader, ignore:
  { :VOTE_REPLY, follower_num, follower_curr_term } ->
    IO.puts("Ignoring Vote Reply from Server #{follower_num} to Server #{s.server_num}")
    # Debug.received("Discard Reply to old Vote Request #{inspect msg}")
    s

    # IO.inspect(s, label: "s after receive_vote_reply_from_follower finished - in server.ex")
    # s

    # ________________________________________________________
    # (iv) When a leader is elected
    # {:LEADER_ELECTED, _candidate_num, candidate_curr_term} ->
    #   IO.puts("leader message received")
    #   Process.exit(s.selfP, :kill)

    {:LEADER_ELECTED, _leaderP, leader_curr_term} when leader_curr_term < curr_term ->
      IO.puts("Old leader message. Discard message.")
      s

    {:LEADER_ELECTED, leaderP, leader_curr_term} -> # when candidate_curr_term == curr_term
      s = s |> Vote.receive_leader(leaderP, leader_curr_term)
      s



  # ---------------- APPEND-ENTRIES MESSAGES ------------------
  # If receive heartbeat, aka an empty append entries request
  # From: Leader --> To: Candidate
  { :APPEND_ENTRIES_REQUEST, leaderTerm, commitIndex } ->
    # IO.puts("Received heartbeat, Server #{s.server_num} restarting timer - Line 111 server.ex")
    s = s |> Timer.restart_election_timer()
    s

  { :APPEND_ENTRIES_REQUEST, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex} ->
    IO.puts("Received aeReq from leader, processing - Line 116 server.ex")
    # IO.inspect(s, label: "server.ex Line 117")
    s = AppendEntries.receive_append_entries_request(s, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex)
    s

    # { :APPEND_ENTRIES_REQUEST, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex} when s.role == :LEADER->
    #   IO.puts("Leader received aeReq from leader, processing - Line 122 server.ex")
    #   # IO.inspect(s, label: "server.ex Line 117")
    #   s


  # { :APPEND_ENTRIES_REQUEST, client_msg, leader_term } ->
  #   s = AppendEntries.receive_append_entries_request(s, client_msg, leader_term)

  # # If the receiver's term < curr_term, do not append
  # { :APPEND_ENTRIES_REQUEST, mterm, m } when mterm < curr_term -> # Reject send Success=false and newer term in reply
  #   s = s |> Debug.message("-areq", "stale #{mterm} #{inspect m}")
  #         |> AppendEntries.send_entries_reply_to_leader(m.leaderP, false)

#   # ________________________________________________________
#   { _mtype, mterm, _m } = msg when mterm < curr_term ->     # Discard any other stale messages
#     s |> Debug.received("stale #{inspect msg}")

  # ________________________________________________________
  # If leader
  {:APPEND_ENTRIES_REPLY, followerP, followerTerm, success, followerLastIndex} when s.role == :LEADER ->
    IO.puts('Leader #{s.server_num} received aeReply')
    # If follower term larger than mine, stepdown:
    s = if followerTerm > curr_term do
      IO.puts("Leader term #{s.curr_term} smaller than follower term #{followerTerm}, stepdown")
      s = Vote.stepdown(s, followerTerm)
    else
      IO.puts("Leader #{s.server_num} processing aeReply")
      s = AppendEntries.receive_append_entries_reply_from_follower(s, followerP, followerTerm, success, followerLastIndex)
    end
    s

  # If not leader, ignore:
  {:APPEND_ENTRIES_REPLY, followerP, followerTerm, success, followerLastIndex} ->
    IO.puts("Server #{s.server_num} ignored aeReply as no longer leader")
    s
#   { :APPEND_ENTRIES_REPLY, mterm, m } = msg ->              # Follower >> Leader
#     s |> Debug.message("-arep", msg)
#       |> AppendEntries.receive_append_entries_reply_from_follower(mterm, m)


  # ________________________________________________________
  { :APPEND_ENTRIES_TIMEOUT, term, followerP } = msg ->   # Leader >> Leader
    s = if s.role == :LEADER && term == curr_term do
      # IO.puts("Leader received aeTimeout")
      s = s
      |> Debug.message("-atim", msg)
      |> AppendEntries.send_entries_to_followers(followerP)
    else
      IO.puts("Server received outdated aeTimeout (either not leader/ from older term")
      s
    end

    s

  # ________________________________________________________
  { :CLIENT_REQUEST, m } = msg when s.role == :LEADER ->                  # Client >> Leader
    s = s
      |> Debug.message("-creq", msg)
      |> ClientReq.receive_request_from_client(m)
    # IO.inspect(s.log, label: "Leader logs - server.ex Line 179")
    s

  { :CLIENT_REQUEST, m } = msg ->                                         # Client >> Follower/Candidate (IGNORE)
   #  send m.clientP, {:CLIENT_REPLY, m.cid, :NOT_LEADER, s.leaderP}
    s

  { :DB_REPLY, _result, db_seqnum, client_request } when s.role == :LEADER ->     # DB Replication successful for leader
    s = ClientReq.receive_reply_from_db(s, db_seqnum, client_request)
    IO.puts("Database replicated log #{inspect (client_request)}")
    s

  { :DB_REPLY, _result, db_seqnum, client_request } when s.last_applied < db_seqnum ->   # DB Replication successful for follower/candidate
    s = State.last_applied(s, db_seqnum)
    IO.puts("Commit request log #{inspect (client_request)} to local database")
    s

  { :DB_REPLY, _result, db_seqnum, client_request } -> # catch misordered messages
    IO.puts("Ignore dbReply for log #{inspect (client_request)}")
    s

  {:COMMIT_ENTRIES_REQUEST, db_seqnum} when db_seqnum > s.last_applied -> # database send reply to leader, then follower can commit the request to its local machine
    for index <- (s.last_applied+1)..min(db_seqnum, s.commit_index) do
      IO.puts("Follower committ log #{index} to database")
      send s.databaseP, { :DB_REQUEST, Log.request_at(s, index), index}
    end
    s

  {:COMMIT_ENTRIES_REQUEST, db_seqnum} -> # follower ignore the request which has lower index than last_applied
    IO.puts("Follower already committed log #{db_seqnum} to database")
    s

  # { :DB_RESULT, result, db_seqnum } ->                       # DB Replication unsucessful - did not match db sequence
  #   IO.puts("Database did not replicate log #{db_seqnum}.")
  #   s

    unexpected ->
      Helper.node_halt("************* Server: unexpected message #{inspect unexpected}")

  end # receive

  Server.next(s)
end # next



# """  Omitted
# def follower_if_higher(s, mterm) do
# def become_follower(s, mterm) do
# def become_candidate(s) do
# def become_leader(s) do
# def execute_committed_entries(s) do
# """

end # Server
