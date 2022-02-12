
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do

# s = server process state (c.f. self/this)

def receive_election_timeout(s) do
  # s - me, the candidate or follower
  # Update state of candidate (s)
  IO.puts("Server #{s.server_num} received election timeout")
  if s.role == :CANDIDATE || s.role == :FOLLOWER do
    s = s
      |> State.role(:CANDIDATE)         # change role
      |> State.inc_term()               # increment current term
      |> State.voted_for(s.selfP)       # vote for self
      |> State.add_to_voted_by(s.selfP) # add self to list of voters
    # (ii) send vote requests to other servers
    for n <- s.servers do
      # IO.inspect(n, label: "n in for loop")
      send n, { :VOTE_REQUEST, s } #
      State.inc_election(n)
      Timer.restart_append_entries_timer(s,n)
    end
    IO.puts("Server #{s.server_num} runs for candidate")
  end
end


def receive_vote_request_from_candidate(follower, candidate) do
  # candidate - server that is requesting for my vote
  # follower - me (server)
  IO.puts("Server #{follower.server_num} received vote req for Server #{candidate.server_num}")
  if candidate.curr_term > follower.curr_term do
    stepdown(follower, candidate.curr_term)
  end

  if (candidate.curr_term == follower.curr_term) && (follower.voted_for == nil || follower.voted_for == candidate.selfP) do
    follower = follower
      |> State.voted_for(candidate.selfP)             # vote for candidate
      |> Timer.restart_election_timer()               # restart election timer
      send candidate.selfP, {:VOTE_REPLY, follower}
      IO.puts("Server #{follower.server_num} voted for Server #{candidate.server_num}")
  end
end

def receive_vote_reply_from_follower(candidate, follower) do
  if candidate.curr_term > follower.curr_term do
    stepdown(follower, candidate.curr_term)
  end

  if candidate.curr_term == follower.curr_term && candidate.role == :CANDIDATE do
    candidate = candidate
      |> State.add_to_voted_by(follower)
      |> Timer.cancel_append_entries_timer(follower) # should we cancel or restart?

    if State.vote_tally(candidate) > candidate.majority do
      IO.puts("New leader elected! Server #{candidate.server_num} is leader for #{candidate.curr_term}")
      State.role(candidate, :LEADER)
      for n <- candidate.servers do
        send n, {:APPEND_ENTRIES_REQUEST, candidate}
      end
    end
  end
end

defp stepdown(server, term) do
  server = server
    |>State.curr_term(term)                   # update to latest term
    |>State.role(:FOLLOWER)                   # make sure become follower
    |>State.voted_for(nil)                    # clear any previous votes
    |>Timer.restart_election_timer()          # restart election timer
end

end # Vote




# defp send_vote_reply_to_candidate (candidate, selected) do

# { :VOTE_REQUEST, candidate } when candidate.curr_term < curr_term ->     # Reject, send voted Granted=false and newer_term in reply
# s |> Debug.message("-vreq", "stale #{mterm} #{inspect m}")
#   |> Vote.send_vote_reply_to_candidate(m.candidateP, false)
