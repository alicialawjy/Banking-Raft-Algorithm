
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Log do

# s = server state (c.f. self/this)

# implemented as a Map indexed from 1.

def new(),                do: Map.new()                  # used when process state is initialised
def new(s),               do: Map.put(s, :log, Map.new)  # not currently used
def new(s, log),          do: Map.put(s, :log, log)      # only used below

def last_index(s),        do: map_size(s.log)

def entry_at(s, index),   do: s.log[index]
def request_at(s, index), do: s.log[index].request
def term_at(_s, 0),       do: 0
def term_at(s, index),    do: s.log[index].term
def last_term(s),         do: Log.term_at(s, Log.last_index(s))

def get_entries(s, range), do:                    # e.g return s.log[3..5]
  Map.take(s.log, Enum.to_list(range))

def append_entry(s, entry), do:
  Log.new(s, Map.put(s.log, Log.last_index(s)+1, entry))

def merge_entries(s, entries), do:                # entries should be disjoint
  Log.new(s, Map.merge(s.log, entries))

def delete_entries(s, range), do:                 # e.g. delete s.log[3..5] keep rest
  Log.new(s, Map.drop(s.log, Enum.to_list(range)))

def delete_entries_from(s, from), do:             # delete s.log[from..last] keep rest
  Log.delete_entries(s, from .. Log.last_index(s))

end # Log
