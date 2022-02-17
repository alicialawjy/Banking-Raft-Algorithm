
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do

# s = server process state (c.f. self/this)

def receive_election_timeout(s) do
  # s - the server that timed out. Has to be either candidate or follower (not leader)

  # (i) Run for candidate
  IO.puts("Server #{s.server_num} runs for candidate")
  s = s
    |> State.role(:CANDIDATE)         # change role to candidate
    |> State.inc_term()               # increment current term
    |> State.inc_election()           # increment election term (???)
    |> State.voted_for(s.server_num)       # vote for self
    |> State.add_to_voted_by(s.server_num) # add self to list of voters
    |> Timer.restart_election_timer() # restart election timer

  # IO.inspect(s, label: "server after running for candidate")

  # (ii) Send vote requests to other servers except myself (as have voted in (i))
  for n <- s.servers do
    if n != s.selfP do
      send n, { :VOTE_REQUEST, State.get_info(s) }
      # Timer.restart_append_entries_timer(s,n)
    end
  end

  s # return
end

def receive_vote_request_from_candidate(follower, candidate_curr_term, candidate_num, candidate_id) do
  # Candidate - has term >= follower term currently and is requesting my vote
  # Follower - me (server)

  # Stepdown is candidate term is greater
  follower = if candidate_curr_term > follower.curr_term do
    follower = stepdown(follower, candidate_curr_term)
    IO.puts("Server #{follower.server_num} stepdown when receive vote request")
    follower
  else
    follower
  end

  # Check if stepdown implemented correctly
  IO.inspect(follower, label: "s after stepdown function")

  # If candidate term == follower term and follower has not voted
  follower = if ((candidate_curr_term == follower.curr_term) && (follower.voted_for == nil)) do
    follower
      # |> State.inc_election()                         # keep up-to-date with the election term incase of outdated election timeout msg (???)
      |> State.voted_for(candidate_num)             # vote for candidate
      |> Timer.restart_election_timer()               # restart election timer
  else
    follower # in case already voted for someone else
  end

  # Send vote reply to candidate if voted for them
  if follower.voted_for == candidate_num do
    send candidate_id, {:VOTE_REPLY, follower.server_num, follower.curr_term}
    # Check if follower state correctly reflects vote
    IO.puts("Server #{follower.server_num} voted for Server #{candidate_num}")
    IO.inspect(follower, label: "After voting")
  end

  follower # return
end

def receive_vote_reply_from_follower(candidate, follower_num, follower_curr_term) do
  # Follower voted for candidate.
  # NOTE: (i) Follower must have same curr_term as candidate.
  #       (ii) Candidate servers only. If leader, should not process vote replies anymore.

  # Stepdown if follower term is larger
  candidate = if candidate.curr_term < follower_curr_term do
    stepdown(candidate, follower_curr_term)
    IO.puts("Candidate #{candidate.server_num} stepdown at vote reply")
    candidate
  else
    candidate
  end

  # If candidate.curr_term == follower.curr_term, process voter
  candidate = if candidate.curr_term == follower_curr_term do
    candidate
    |> State.add_to_voted_by(follower_num)
  else
    candidate
  end
  IO.puts("Processed vote from Server #{follower_num} for Server #{candidate.server_num}")
  IO.inspect(candidate, label: "added new voter")

  # Check if majority. If yes, become leader
  candidate = if State.vote_tally(candidate) >= candidate.majority do
    candidate = become_leader(candidate)
    IO.puts("New leader elected! Server #{candidate.server_num} is leader for Term #{candidate.curr_term}")
    IO.inspect(candidate, label: "new leader")
    candidate
  else
    candidate
  end
end

defp become_leader(candidate) do
  # Change candidate status to leader
  candidate = candidate
    |> State.role(:LEADER)                          # Update role to leader
    |> Timer.cancel_election_timer()                # Remove leader's election timer (not needed)
    |> State.next_index(Log.last_index(candidate))  # Update it's next index with all of its followers to its log length

  # Build the append entries timer for its followers
  aeTimer =
    for i <- candidate.servers,
    into: Map.new
    do
      if i != candidate.selfP do
        {i, Timer.leader_create_aeTimer(candidate, i)}
      else
        {i, nil}
      end
    end

  # Append timer to leader
  candidate = State.add_append_entries_timer(candidate, aeTimer)
  IO.inspect(candidate, label: "leader after added aeTimer")

  # Send messages to followers to announce leadership
  for n <- candidate.servers do
    if n != candidate.selfP do
      send n, {:LEADER_ELECTED, candidate.server_num, candidate.curr_term} # Inform others that server is now the leader for the term
      send n, {:APPEND_ENTRIES_REQ, candidate.curr_term, candidate.commit_index } # TESTING: send empty append entries req, aka a heartbeat
      # AppendEntries.send_entries_to_followers(candidate, n, nil)
    end #if
  end #for

  IO.inspect(candidate, label: "leader after sending messages")

  candidate
end

def receive_leader(follower, candidate_num, candidate_curr_term) do
  # If follower term is < ledaer term, update follower's curr_term
  follower = if follower.curr_term < candidate_curr_term do
    State.curr_term(follower, candidate_curr_term)
  else
    follower
  end

  # Update follower's leaderP
  follower = follower
    |> State.leaderP(candidate_num)
    |> Timer.restart_election_timer()

  follower
end

def stepdown(server, term) do
  # Used when received message from another server of a larger term.

  # IO.puts("Server #{server.server_num} stepdown")
  server = server
    |>State.curr_term(term)                   # update to latest term
    |>State.role(:FOLLOWER)                   # make sure become follower
    |>State.voted_for(nil)                    # clear any previous votes
    |>State.new_voted_by()                    # clear votes
    |>Timer.cancel_all_append_entries_timers()# clear aeTimer if any (only for past :LEADERS)
    |>Timer.restart_election_timer()          # restart election timer
  server
end

end # Vote
