# Alicia Law(ajl115) and Ye Liu(yl10321)
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do

# s = server process state (c.f. self/this)

def receive_election_timeout(s) do
  # Called when received :ELECTION_TIMEOUT message.
  # s - A Follower/ Candidate server that timed out (never a Leader).

  # (i) Run for candidate
  # IO.puts("Server #{s.server_num} runs for candidate in term #{s.curr_term+1}")
  s = s
    |> State.role(:CANDIDATE)               # Change role to candidate
    |> State.inc_term()                     # Increment current term
    |> State.voted_for(s.server_num)        # Vote for self
    |> State.add_to_voted_by(s.server_num)  # Add self to list of voters
    |> Timer.restart_election_timer()       # Restart election timer

  # (ii) Send vote requests to other servers except myself (as already voted in (i))
  for n <- s.servers do
    if n != s.selfP do
      send n, { :VOTE_REQUEST, State.get_info(s) }
    end
  end

  s # return
end

def receive_vote_request_from_candidate(follower, candidate_curr_term, candidate_num, candidate_id, candidateLastLogTerm, candidateLastLogIndex) do
  # Called when received :VOTE_REQUEST message by candidates who have curr_term >= follower's curr_term.
  # Inputs:
  #   - follower              : receipient of the vote request
  #   - candidate_curr_term   : candidate's election term
  #   - candidate_num         : candidate's server_num
  #   - candidate_id          : candidate's <PID>
  #   - candidateLastLogTerm  : the term  of the last log entry
  #   - candidateLastLogIndex : the index of the last log entry

  # (i) Stepdown if candidate term is greater
  follower = if candidate_curr_term > follower.curr_term do
    follower = stepdown(follower, candidate_curr_term)
    # IO.puts("Server #{follower.server_num} stepdown at receiving vote request")
    follower
  else
    follower
  end

  # (ii) Follower will vote for candidate if:
  #      1. Follower has not voted                     : follower.voted_for == nil, and
  #      2a. Candidate has a larger LastLogTerm, or    : candidateLastLogTerm > followerLastLogTerm)
  #      2b. Candidate's LastLogTerm is the same, and  : candidateLastLogTerm == followerLastLogTerm) but
  #                      LastLogIndex is larger        : candidateLastLogIndex >= Log.last_index(follower))

  followerLastLogTerm = Log.term_at(follower, Log.last_index(follower))
  follower = if (follower.voted_for == nil) && ((candidateLastLogTerm > followerLastLogTerm) || (candidateLastLogTerm == followerLastLogTerm && candidateLastLogIndex >= Log.last_index(follower))) do
    follower
      |> State.voted_for(candidate_num)     # Vote for candidate
      |> Timer.restart_election_timer()     # Restart election timer
  else
    follower                                # If not suited, do not vote and let election timer runout
  end

  # (iii) Send vote reply to candidate if voted for them
  if follower.voted_for == candidate_num do
    send candidate_id, {:VOTE_REPLY, follower.server_num, follower.curr_term}
    # IO.puts("Server #{follower.server_num} voted for Server #{candidate_num} in term #{follower.curr_term}")
  end

  follower # return
end

def receive_vote_reply_from_follower(candidate, follower_num, follower_curr_term) do
  # Called when a follower voted for candidate and sends a :VOTE_REPLY.
  # Inputs:
  #   - candidate          : candidate server
  #   - follower_num       : follower's server_num
  #   - follower_curr_term : follower's current term

  # (i) Stepdown if follower's term is larger
  candidate = if candidate.curr_term < follower_curr_term do
    stepdown(candidate, follower_curr_term)
    # IO.puts("Candidate #{candidate.server_num} stepdown at vote reply")
    candidate
  else
    candidate
  end

  # (ii) If candidate.curr_term == follower.curr_term, add voter into add_to_voted_by list
  candidate = if candidate.curr_term == follower_curr_term do
    # IO.puts("Processed vote from Server #{follower_num} for Server #{candidate.server_num}")
    candidate |> State.add_to_voted_by(follower_num)
  else
    candidate
  end

  # (iii) Check if majority reached. If yes, become leader
  candidate = if State.vote_tally(candidate) >= candidate.majority do
    candidate = become_leader(candidate)
    # IO.puts("New leader elected! Server #{candidate.server_num} is leader for Term #{candidate.curr_term}")
    # IO.puts("Leader #{candidate.server_num} got votes from #{inspect candidate.voted_by}")
    candidate
  else
    candidate
  end
end

defp become_leader(candidate) do
  # Change Candidate to Leader
  # Inputs: candidate (server)

  #(i) Update candidate's state.
  candidate = candidate
    |> State.role(:LEADER)                # Update role to leader
    |> Timer.cancel_election_timer()      # Remove election timer (not needed for leaders)
    |> State.init_next_index()            # Update it's next index with all of its followers to its log length


  # (ii) Build the append entries timer for its followers and append to candidate state.
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

  candidate = State.add_append_entries_timer(candidate, aeTimer)

  # (iii) Send messages to followers to announce leadership for this term.
  for n <- candidate.servers do
    if n != candidate.selfP do
      send n, {:LEADER_ELECTED, candidate.selfP, candidate.curr_term}
    end # if
  end # for

  candidate # return
end

def receive_leader(follower, leaderP, leader_curr_term) do
  # When followers receive a message from a new leader.

  # If follower term < leader term, update follower's curr_term to match leader's
  follower = if follower.curr_term < leader_curr_term do
    State.curr_term(follower, leader_curr_term)
  else
    follower
  end

  follower = follower
    |> stepdown(leader_curr_term)   # Make sure server stepsdown in case if was a past leader/candidate
    |> State.leaderP(leaderP)       # Update the leaderP in State

  follower # return
end

def stepdown(server, term) do
  # Used when received message from another server of a larger term.

  server = server
    |>State.curr_term(term)                     # Update to latest term
    |>State.role(:FOLLOWER)                     # Change role to Follower
    |>State.voted_for(nil)                      # Clear any previous votes
    |>State.new_voted_by()                      # Clear any voted_by  (if any, only for past :LEADERS)
    |>Timer.cancel_all_append_entries_timers()  # Clear aeTimer       (if any, only for past :LEADERS)
    |>Timer.restart_election_timer()            # Restart election timer

  server # return
end

end # Vote
