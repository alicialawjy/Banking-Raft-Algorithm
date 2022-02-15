
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
  curr_election = s.curr_election                  # used to discard old election timeouts

  s = receive do

  # ---------------- VOTE-RELATED MESSAGES ------------------
  # (i) When election timer runs out
  # From: Self {Follower, Candidate} >> To: Self
  # If
  { :ELECTION_TIMEOUT, mterm, melection } = msg when mterm < curr_term ->
    IO.puts("Old Election Timeout for Server #{s.server_num}")
    s |> Debug.received("Old Election Timeout #{inspect msg}")
    s

  { :ELECTION_TIMEOUT, mterm, melection } = msg when (s.role != :LEADER) -> # equal or larger than curr_term
    IO.puts("Server #{s.server_num} Election Timeout - START")
    s = s
      |> Debug.received("-etim", msg)
      |> Vote.receive_election_timeout()

    IO.inspect(s, label: "s after election timeout finished - in server.ex")
    s
  # ________________________________________________________
  # (ii) When follower received vote request from candidate
  # If candidate term is lower, do not vote
  { :VOTE_REQUEST, [candidate_curr_term, candidate_num, _candidate_id] } when candidate_curr_term < curr_term ->
    IO.puts("Server #{s.server_num} received vote req from Server #{candidate_num} but did not vote")
    s

  # If candidate term >= ours, process:
  { :VOTE_REQUEST, [candidate_curr_term, candidate_num, candidate_id] } = msg ->
    s = s
      |> Debug.message("-vreq", msg)
      |> Vote.receive_vote_request_from_candidate(candidate_curr_term, candidate_num, candidate_id)

    IO.inspect(s, label: "s #{s.server_num} after receive_vote_request_from_candidate #{candidate_num} finished - in server.ex")
    s
  # ________________________________________________________
  # (iii) When candidate received a vote reply from a follower
  # follower_curr_term: the election term that the follower voted in.

  # If the vote reply was for an old election, discard:
  { :VOTE_REPLY, follower_num, follower_curr_term } when follower_curr_term < curr_term ->
    IO.puts("Received Vote Reply from Server #{follower_num} to Server #{s.server_num} - START")
    # Debug.received("Discard Reply to old Vote Request #{inspect msg}")
    s

  # If the vote reply is for this term's election, process it:
  { :VOTE_REPLY, follower_num, follower_curr_term } = msg when s.role == :CANDIDATE -> #when follower_curr_term == curr_term
    s = s
      |> Debug.message("-vrep", msg)
      |> Vote.receive_vote_reply_from_follower(follower_num, follower_curr_term)
    # else
    #   s
    # end

    IO.inspect(s, label: "s after receive_vote_reply_from_follower finished - in server.ex")
    s

    # ________________________________________________________
    # (iv) When a leader is elected
    {:LEADER_ELECTED, _candidate_num, candidate_curr_term} ->
      IO.puts("leader message received")
      Process.exit(s.selfP, :kill)

    # {:LEADER_ELECTED, _candidate_num, candidate_curr_term} when candidate_curr_term < curr_term ->
    #   IO.puts("Old leader message. Discard message.")
    #   s

    # {:LEADER_ELECTED, candidate_num, candidate_curr_term} -> # when candidate_curr_term == curr_term
    #   s = s |> Vote.receive_leader(candidate_num, candidate_curr_term)
    #   s
  # ---------------- APPEND-ENTRIES MESSAGES ------------------
  # If the receiver's term < curr_term, do not append
  { :APPEND_ENTRIES_REQUEST, mterm, m } when mterm < curr_term -> # Reject send Success=false and newer term in reply
    s |> Debug.message("-areq", "stale #{mterm} #{inspect m}")
      |> AppendEntries.send_entries_reply_to_leader(m.leaderP, false)

#   # ________________________________________________________
#   { _mtype, mterm, _m } = msg when mterm < curr_term ->     # Discard any other stale messages
#     s |> Debug.received("stale #{inspect msg}")

  # ________________________________________________________
  # { :APPEND_ENTRIES_REQUEST, mterm, m } = msg ->            # Leader >> All
  #   s |> Debug.message("-areq", msg)
  #     |> AppendEntries.receive_append_entries_request_from_leader(mterm, m)

#   { :APPEND_ENTRIES_REPLY, mterm, m } = msg ->              # Follower >> Leader
#     s |> Debug.message("-arep", msg)
#       |> AppendEntries.receive_append_entries_reply_from_follower(mterm, m)

#   # ________________________________________________________

#   { :APPEND_ENTRIES_TIMEOUT, _mterm, followerP } = msg ->   # Leader >> Leader
#     s |> Debug.message("-atim", msg)
#       |> AppendEntries.receive_append_entries_timeout(followerP)

#   # ________________________________________________________
#   { :CLIENT_REQUEST, m } = msg ->                           # Client >> Leader
#     s |> Debug.message("-creq", msg)
#       |> ClientReq.receive_request_from_client(m)

#   # { :DB_RESULT, _result } when false -> # don't process DB_RESULT here

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
