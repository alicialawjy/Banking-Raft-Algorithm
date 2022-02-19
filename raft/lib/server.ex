
# distributed algorithms, Alicia Law and Ye Liu, 19 Feb 2022
# coursework, raft consensus, v2

defmodule Server do

# s = server process state (c.f. self/this)

# _________________________________________________________ Server.start()
def start(config, server_num) do
  config = config
    |> Configuration.node_info("Server", server_num)
    |> Debug.node_starting()
  #IO.puts "server #{server_num} starts"

  receive do
  { :BIND, servers, databaseP } ->
    s = State.initialise(config, server_num, servers, databaseP)
    s |> Timer.restart_election_timer()
    s |> Server.next()
  end # receive
end # start

# _________________________________________________________ next()
def next(s) do
  curr_term = s.curr_term    # server's current term

  s = receive do
  # ------------------------------------------------------- #
  # ---------------- VOTE-RELATED MESSAGES ---------------- #
  # ------------------------------------------------------- #

  # ________________ I. ELECTION TIMEOUT __________________ #
  # From: Self (Follower/Candidate)  >> To: Self (Follower/Candidate)
  # Description: when election timer runs out
  # Message variables: mterm - the curr_term during which the election timeout happened

  # If the election timeout message was from an old term, ignore:
  { :ELECTION_TIMEOUT, mterm, _melection } when mterm < curr_term ->
    # #IO.puts("Server #{s.server_num} ignored old election timeout: message term = #{mterm} but curr_term = #{curr_term}")
    s

  # Otherwise (mterm > curr_term) and if message sent to Follower/Candidate (not Leader), process it:
  { :ELECTION_TIMEOUT, _mterm, _melection } when (s.role != :LEADER) ->
    #IO.puts("Server #{s.server_num} Election Timeout - START")
    s = Vote.receive_election_timeout(s)

  { :ELECTION_TIMEOUT, _mterm, _melection } ->
    s

  # _________________ II. VOTE REQUEST ____________________ #
  # From: Candidate >> To: Follower
  # Description: when received vote request from candidate.
  # Message variables: see description in Vote.receive_vote_request_from_candidate

  # If Candidate's term is lower, do not vote. Ignore:
  { :VOTE_REQUEST, [candidate_curr_term, candidate_num, _candidate_id, _candidateLastLogTerm, _candidateLastLogIndex] } when candidate_curr_term < curr_term ->
    #IO.puts("Server #{s.server_num} received vote req from Server #{candidate_num} but did not vote")
    s

  # Otherwise, consider the candidate:
  { :VOTE_REQUEST, [candidate_curr_term, candidate_num, candidate_id, candidateLastLogTerm, candidateLastLogIndex] } ->
    s = Vote.receive_vote_request_from_candidate(s, candidate_curr_term, candidate_num, candidate_id, candidateLastLogTerm, candidateLastLogIndex)


  # ____________________ III. VOTE REPLY ____________________ #
  # From: Follower >> To: Candidate
  # Description: when received a vote reply from followers.
  # Message variables:
  #   - follower_num       : follower's server_num
  #   - follower_curr_term : follower's current term

  # If the vote reply was for an old election, discard:
  { :VOTE_REPLY, follower_num, follower_curr_term } when follower_curr_term < curr_term ->
    # #IO.puts("Old Vote Reply from Server #{follower_num} to Server #{s.server_num}. Ignored.")
    s

  # Else if, the server is still a candidate and vote reply is for this term's election, accept:
  { :VOTE_REPLY, follower_num, follower_curr_term } = msg when s.role == :CANDIDATE ->
    # #IO.puts("Server #{s.server_num} received Server #{follower_num}'s vote reply. Processing.")
    s = Vote.receive_vote_reply_from_follower(s, follower_num, follower_curr_term)

  # Else, server is no longer a Candidate (either Follower/Leader), ignore:
  { :VOTE_REPLY, follower_num, _follower_curr_term } ->
    # #IO.puts("#{s.role} Server #{follower_num} received Server #{s.server_num} vote reply. Ignored.")
    s

    # __________________ IV. LEADER ELECTED ____________________ #
    # From: New Leader >> To: Candidate/ Follower
    # Description: received when a new leader has been elected.
    # Message variables:
    #   - leaderP          : leader's <PID>
    #   - leader_curr_term : leader's current term

    # Run to test 1 round of election.
    # {:LEADER_ELECTED, _candidate_num, candidate_curr_term} ->
    #   #IO.puts("leader message received")
    #   Process.exit(s.selfP, :kill)

    # If it is a old leader elected message, ignore.
    {:LEADER_ELECTED, _leaderP, leader_curr_term} when leader_curr_term < curr_term ->
      #IO.puts("Old leader message (From term #{leader_curr_term}, Now term #{curr_term}). Discard message.")
      s

    # Otherwise, process new leader.
    {:LEADER_ELECTED, leaderP, leader_curr_term} ->
      s = s |> Vote.receive_leader(leaderP, leader_curr_term)
      s


  # ------------------------------------------------------- #
  # ---------------- APPEND-ENTRIES MESSAGES -------------- #
  # ------------------------------------------------------- #

  # ______________ I. APPEND-ENTRIES REQUEST ______________ #
  # From: Leader --> To: Followers
  # Description: received aeRequest from leader
  # Message Variables:
  #   - leaderTerm    : leader's curr_term
  #   - commitIndex   : leader's commitIndex
  #   - prevIndex     : the index where leader and follower's logs coincide
  #   - prevTerm      : the log's term at prevIndex
  #   - leaderEntries : the leader's logs from [prevIndex + 1 .. end]

  # Heartbeat
  { :APPEND_ENTRIES_REQUEST, _leaderTerm, _commitIndex } ->
    # #IO.puts("Server #{s.server_num} received heartbeat, restarting timer - Line 125 server.ex")
    s = Timer.restart_election_timer(s)

  # New Append Entries Request
  { :APPEND_ENTRIES_REQUEST, leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex} ->
    # #IO.puts("Server #{s.server_num} received aeReq from leader, processing - Line 130 server.ex")
    s = s
      |> Timer.restart_election_timer()
      |> AppendEntries.receive_append_entries_request(leaderTerm, prevIndex, prevTerm, leaderEntries, commitIndex)


  # ______________ II. APPEND-ENTRIES REPLY ______________ #
  # If leader
  {:APPEND_ENTRIES_REPLY, followerP, followerTerm, success, followerLastIndex} when s.role == :LEADER ->
    # If follower term larger than mine, stepdown:
    s = if followerTerm > curr_term do
      #IO.puts("Leader term #{s.curr_term} smaller than follower term #{followerTerm}, stepdown")
      s = Vote.stepdown(s, followerTerm)
    else
      # #IO.puts("Leader #{s.server_num} processing aeReply")
      s = AppendEntries.receive_append_entries_reply_from_follower(s, followerP, followerTerm, success, followerLastIndex)
    end
    s

  # If not leader, ignore:
  {:APPEND_ENTRIES_REPLY, _followerP, _followerTerm, _success, _followerLastIndex} ->
    # #IO.puts("Server #{s.server_num} ignored aeReply as no longer leader")
    s


  # ______________ III. APPEND-ENTRIES TIMEOUT ______________ #
  { :APPEND_ENTRIES_TIMEOUT, term, followerP } = msg ->   # Leader >> Leader
    s = if s.role == :LEADER && term == curr_term do
      # #IO.puts("Leader received aeTimeout")
      s = s
      |> Debug.message("-atim", msg)
      |> AppendEntries.send_entries_to_followers(followerP)
    else
      # #IO.puts("Server received outdated aeTimeout (either not leader/ from older term")
      s
    end

    s

  # ------------------------------------------------------- #
  # ------------------- CLIENT REQUESTS ------------------- #
  # ------------------------------------------------------- #

  { :CLIENT_REQUEST, m } = msg when s.role == :LEADER ->                  # Client >> Leader
    s = s
      |> Debug.message("-creq", msg)
      |> ClientReq.receive_request_from_client(m)
    # IO.inspect(s.log, label: "Leader logs - server.ex Line 179")
    s

  { :CLIENT_REQUEST, m } = msg ->                                         # Client >> Follower/Candidate (IGNORE)
   send m.clientP, {:CLIENT_REPLY, m.cid, :NOT_LEADER, s.leaderP, s.server_num}
    s

  # ------------------------------------------------------- #
  # --------------------- DB MESSAGES --------------------- #
  # ------------------------------------------------------- #
  { :DB_REPLY, _result, db_seqnum, client_request } when s.role == :LEADER ->     # DB Replication successful for leader
    s = ClientReq.receive_reply_from_db(s, db_seqnum, client_request)
    # #IO.puts("Database replicated log #{inspect (client_request)}")
    s

  { :DB_REPLY, _result, db_seqnum, client_request } when s.last_applied < db_seqnum ->   # DB Replication successful for follower/candidate
    s = State.last_applied(s, db_seqnum)
    # #IO.puts("Commit request log #{inspect (client_request)} to local database")
    s

  { :DB_REPLY, _result, _db_seqnum, client_request } -> # catch misordered messages
    # #IO.puts("Ignore dbReply for log #{inspect (client_request)}")
    s

  {:COMMIT_ENTRIES_REQUEST, db_seqnum} when db_seqnum > s.last_applied -> # database send reply to leader, then follower can commit the request to its local machine
    for index <- (s.last_applied+1)..min(db_seqnum, s.commit_index) do
      # #IO.puts("Follower committ log #{index} to database")
      send s.databaseP, { :DB_REQUEST, Log.request_at(s, index), index}
    end
    s

  {:COMMIT_ENTRIES_REQUEST, db_seqnum} -> # follower ignore the request which has lower index than last_applied
    # #IO.puts("Follower already committed log #{db_seqnum} to database")
    s

  # { :DB_RESULT, result, db_seqnum } ->                       # DB Replication unsucessful - did not match db sequence
  #   #IO.puts("Database did not replicate log #{db_seqnum}.")
  #   s

  # ------------------------------------------------------- #
  # ---------------------- UNEXPECTED --------------------- #
  # ------------------------------------------------------- #
    unexpected ->
      Helper.node_halt("************* Server: unexpected message #{inspect unexpected}")

  end # receive

  Server.next(s)
end # next

end # Server
