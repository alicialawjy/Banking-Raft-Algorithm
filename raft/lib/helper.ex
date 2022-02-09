
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

# various helper functions

defmodule Helper do

def node_lookup(name) do
  addresses = :inet_res.lookup(name,:in,:a)
  {a, b, c, d} = hd(addresses) 		# get octets for 1st ipv4 address
  :"#{a}.#{b}.#{c}.#{d}"
end # node_lookup

def node_ip_addr do
  {:ok, interfaces} = :inet.getif()		# get interfaces
  {address, _gateway, _mask}  = hd(interfaces)	# get data for 1st interface
  {a, b, c, d} = address   			# get octets for address
  "#{a}.#{b}.#{c}.#{d}"
end # node_ip_addr

def node_string() do
  "#{node()} (#{node_ip_addr()})"
end # node_string

def node_exit do 	# nicely stop and exit the node
  System.stop(0)	# System.halt(1) for a hard non-tidy node exit
end # node_exit

def node_halt(message) do
  IO.puts "  Node #{node()} exiting - #{message}"
  node_exit()
end # node_halt

def node_exit_after(duration) do
  Process.sleep(duration)
  IO.puts "  Node #{node()} exiting - maxtime reached"
  node_exit()
end # node_exit_after

def node_sleep(message) do
  IO.puts "Node #{node()} Going to Sleep - #{message}"
  Process.sleep :infinity
end # node_sleep

end # Helper
