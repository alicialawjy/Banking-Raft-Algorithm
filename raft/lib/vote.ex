
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do

# s = server process state (c.f. self/this)

def receive_election_timeout(s) do
  # s - the server that timed out. Has to be either candidate or follower (not leader)

  # (i) Run for candidate
  IO.puts("Server #{s.server_num} runs for candidate")
  s = s
    |> Timer.restart_election_timer() # restart election timer
    |> State.role(:CANDIDATE)         # change role to candidate
    |> State.inc_term()               # increment current term
    |> State.inc_election()           # increment election term (???)
    |> State.voted_for(s.server_num)       # vote for self
    |> State.add_to_voted_by(s.server_num) # add self to list of voters

  # IO.inspect(s, label: "server after running for candidate")

  # (ii) Send vote requests to other servers except myself (as have voted in (i))
  for n <- s.servers do
    if n != s.selfP do
      send n, { :VOTE_REQUEST, State.get_info(s) }
      Timer.restart_append_entries_timer(s,n)
    end
    # Timer.restart_append_entries_timer(s,n)
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
    # follower
    #   |>State.curr_term(candidate.curr_term)    # update to latest term
    #   |>State.role(:FOLLOWER)                   # make sure become follower
    #   |>State.voted_for(nil)                    # clear any previous votes
    #   |>Timer.restart_election_timer()          # restart election timer
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
  # Follower voted for candidate. NOTE: Follower must have same curr_term as candidate.

  candidate = if candidate.curr_term < follower_curr_term do
    stepdown(candidate, follower_curr_term)
    IO.puts("Candidate #{candidate.server_num} stepdown at vote reply")
    candidate
  else
    candidate
  end
  #   follower
  #     |>State.curr_term(candidate.curr_term)    # update to latest term
  #     |>State.role(:FOLLOWER)                   # make sure become follower
  #     |>State.voted_for(nil)                    # clear any previous votes
  #     |>Timer.restart_election_timer()          # restart election timer
  # end

  # if candidate.curr_term == follower.curr_term && candidate.role == :CANDIDATE do
  candidate = if candidate.curr_term == follower_curr_term && candidate.role == :CANDIDATE do
    candidate
    |> State.add_to_voted_by(follower_num)
  else
    candidate
  end
    # |> Timer.cancel_append_entries_timer(follower) # should we cancel or restart?
  IO.puts("Processed vote from Server #{follower_num} for Server #{candidate.server_num}")
  IO.inspect(candidate, label: "added new voter")

  candidate = if State.vote_tally(candidate) >= candidate.majority do
    candidate = candidate
    |> State.role(:LEADER)
    |> Timer.cancel_election_timer()
    IO.puts("New leader elected! Server #{candidate.server_num} is leader for Term #{candidate.curr_term}")
    IO.inspect(candidate, label: "new leader")
    candidate
  else
    candidate
  end

  if candidate.role == :LEADER do
    IO.puts("Leader went into if statement")
    for n <- candidate.servers do
      send n, {:LEADER_ELECTED, candidate.server_num, candidate.curr_term}
    end
  end
  IO.inspect(candidate, label: "check if leader")
  candidate # return
end

def receive_leader(follower, candidate_num, candidate_curr_term) do
  # If follower term is < ledaer term, update follower
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

defp stepdown(server, term) do
  # IO.puts("Server #{server.server_num} stepdown")
  server = server
    |>State.curr_term(term)                   # update to latest term
    |>State.role(:FOLLOWER)                   # make sure become follower
    |>State.voted_for(nil)                    # clear any previous votes
    |>State.new_voted_by()                    # clear votes
    |>Timer.restart_election_timer()          # restart election timer
  server
end

end # Vote




# defp send_vote_reply_to_candidate (candidate, selected) do

# { :VOTE_REQUEST, candidate } when candidate.curr_term < curr_term ->     # Reject, send voted Granted=false and newer_term in reply
# s |> Debug.message("-vreq", "stale #{mterm} #{inspect m}")
#   |> Vote.send_vote_reply_to_candidate(m.candidateP, false)
