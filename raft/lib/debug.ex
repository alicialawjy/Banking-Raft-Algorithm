
# distributed algorithms, n.dulay, 8 feb jan 2022
# coursework, raft consensus, v2

defmodule Debug do

# s = server process state (c.f. self/this)

def inc_line_num(s),  do: Map.put(s, :config, Map.put(s.config, :line_num, s.config.line_num+1))
def kpad(key),        do: String.pad_trailing("#{key}", 15)
def lpad(line_num),   do: String.pad_leading("#{line_num}", 4, "0")
def rpad(role),       do: String.pad_trailing("#{role}", 9)
def tpad(term),       do: String.pad_leading("#{term}", 3, "0")
def node_prefix(c),   do: "#{c.node_name}@#{c.node_location}"
def server_prefix(s), do: "server#{s.server_num}-#{lpad(s.config.line_num)} role=#{rpad(s.role)} term=#{tpad(s.curr_term)}"
def map(m),           do: (for {k, v} <- m, into: "" do "\n\t#{kpad(k)}\t#{inspect v}" end) 

def option?(c, option, level), do: 
  String.contains?(c.debug_options, option) and c.debug_level >= level

def mapstr(c, mapname, mapvalue, level), do:
  (if Debug.option?(c, "a", level) do "#{mapname} = #{map(mapvalue)}" else "" end)

# _________________________________________________________ Debug.message()
def message(s, option, message, level \\ 1) do
  unless Debug.option?(s.config, option, level) do s else
    s = inc_line_num(s)
    IO.puts "#{server_prefix(s)} #{option} #{inspect message}"
    s
  end # unless
end # message

# _________________________________________________________ Debug.received()
def received(s, message, level \\ 1) do
  _s = Debug.message(s, "?rec", message, level)
end # received

# _________________________________________________________ Debug.sent()
def sent(s, message, level \\ 1) do
  _s = Debug.message(s, "!snd",  message, level)
end # sent

# _________________________________________________________ Debug.received()
def info(s, message, level \\ 1) do
  _s = Debug.message(s, "!inf", message, level)
end # received

# _________________________________________________________ Debug.state()
def state(s, msg, level \\ 2) do
  unless Debug.option?(s.config, "+state", level) do s else
    s = Debug.inc_line_num(s)
    smap = Map.put(s,    :config, "... OMITTED")
    smap = Map.put(smap, :log, "... OMITTED")
    IO.puts "#{server_prefix(s)} #{msg} #{mapstr(s.config, "STATE", smap, level)}"
    s
  end # unless
end # state

# _________________________________________________________ Debug.node_starting()
def node_starting(c, level \\ 1) do
  if Debug.option?(c, "+node", level) do
    IO.puts("  Node #{node_prefix(c)} starting #{mapstr(c, "CONFIG", c, level)}")
  end # if
  c
end # node_starting

# _________________________________________________________ Debug.role()
def role(s, level \\ 3) do   # paint role each iteration of server
  if Debug.option?(s.config, "R", level) do
    IO.write %{FOLLOWER: "F", LEADER: "L", CANDIDATE: "C"}[s.role]
  end # if
  s
end # role

# _________________________________________________________ Debug.assert()
def assert(s, asserted, message) do
  unless asserted do
    Helper.node_halt("!!!! server #{s.server_num} assert failed #{message}")
  end # unless
  s
end # assert

end # Debug
