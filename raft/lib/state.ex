
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule State do

# s = server process state (c.f. self/this)

# _________________________________________________________ State.initialise()
def initialise(config, server_num, servers, databaseP) do
  # initialise state variables for server
  %{
    # _____________________constants _______________________

    config:       config,             # system configuration parameters (from Helper module)
    server_num:	  server_num,         # server num (for debugging)
    selfP:        self(),             # server's process id
    servers:      servers,            # list of process id's of servers
    num_servers:  length(servers),    # no. of servers
    majority:     div(length(servers),2) + 1,  # cluster membership changes are not supported in this implementation

    databaseP:    databaseP,          # local database - used to send committed entries for execution

    # ______________ elections ____________________________
    election_timer:  nil,            # one timer for all peers
    curr_election:   0,              # used to drop old electionTimeout messages and votereplies
    voted_for:	     nil,            # num of candidate that been granted vote incl self
    voted_by:        MapSet.new,     # set of processes that have voted for candidate incl. candidate

    append_entries_timers: Map.new,   # one timer for each follower

    leaderP:        nil,	     # included in reply to client request

    # _______________raft paper state variables___________________

    curr_term:	  0,                  # current term incremented when starting election
    log:          Log.new(),          # log of entries, indexed from 1
    role:         :FOLLOWER,          # one of :FOLLOWER, :LEADER, :CANDIDATE
    commit_index: 0,                  # index of highest committed entry in server's log
    last_applied: 0,                  # index of last entry applied to state machine of server

    next_index:   Map.new,            # foreach follower, index of follower's last known entry+1
    match_index:  Map.new,            # index of highest entry known to be replicated at a follower
  }
end # initialise

# ______________setters for mutable variables_______________

# log is implemented in Log module

def leaderP(s, v),        do: Map.put(s, :leaderP, v)
def election_timer(s, v), do: Map.put(s, :election_timer, v)
def curr_election(s, v),  do: Map.put(s, :curr_election, v)
def inc_election(s),      do: Map.put(s, :curr_term, s.curr_election + 1)
def voted_for(s, v),      do: Map.put(s, :voted_for, v)
def new_voted_by(s),      do: Map.put(s, :voted_by, MapSet.new)
def add_to_voted_by(s, v),do: Map.put(s, :voted_by, MapSet.put(s.voted_by, v))
def vote_tally(s),        do: MapSet.size(s.voted_by)

def append_entries_timers(s),
                          do: Map.put(s, :append_entries_timers, Map.new)
def append_entries_timer(s, i, v),
                          do: Map.put(s, :append_entries_timers, Map.put(s.append_entries_timers, i, v))


def curr_term(s, v),      do: Map.put(s, :curr_term, v)
def inc_term(s),          do: Map.put(s, :curr_term, s.curr_term + 1)

def role(s, v),           do: Map.put(s, :role, v)
def commit_index(s, v),   do: Map.put(s, :commit_index, v)
def last_applied(s, v),   do: Map.put(s, :last_applied, v)

def next_index(s, v),     do: Map.put(s, :next_index, v)
def next_index(s, i, v),  do: Map.put(s, :next_index, Map.put(s.next_index, i, v))
def match_index(s, v),    do: Map.put(s, :match_index, v)
def match_index(s, i, v), do: Map.put(s, :match_index, Map.put(s.match_index, i, v))


def init_next_index(s) do
  v = Log.last_index(s)+1
  new_next_index = for server <- s.servers, into: Map.new do
    {server, v}
  end
  s |> State.next_index(new_next_index)
end # init_next_index

def init_match_index(s) do
  new_match_index = for server <- s.servers, into: Map.new do {server, 0} end
  s |> State.match_index(new_match_index)
end # init_match_index

end # State
