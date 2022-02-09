
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Vote do

# s = server process state (c.f. self/this)
# defp send_vote_reply_to_candidate (candidate, selected) do
#   # selected (Bool): True if voted for candidate, False otherwise

# end

defp receive_vote_request_from_candidate(candidate_term, candidate, follower) do
  # mterm - candidate's current term
  # m - candidate that i'm voting for/ requesting for my vote
  # (i) if the term is equal, check last index. Vote if candidate index > my index
  # if candidate_term == follower do
  #   # last_index(m)
  # # (ii) if candidate term > my term, vote.
  # else
  #   # send_vote_
  # end



end

# defp receive_vote_reply_from_follower do
#   pass()
# end

defp receive_election_timeout(s) do
  # s - me, the candidate
  # Update state of candidate (s)
  s |> State.role(:CANDIDATE)         # change role
    |> State.inc_term()               # increment current term
    |> State.voted_for(1)             # update voting count
    |> State.add_to_voted_by(s.selfP) # vote for self

  # (ii) send vote requests to other servers
  for n <- s.servers do
    send n, { :VOTE_REQUEST, s.curr_term, s } # ?? m
  end

end
# ... omitted

end # Vote
