# Banking-Raft-Algorithm
Implement and evaluate a simple replicated banking service using the Raft consensus algorithm.

The following are instructions on how to run the system, and how to reproduce interesting experiments. Once all parameters are set, run `cd raft` and `make cluster`.

## Normal situation
Default parameters setting in 'configuration.ex':
```
Number of servers: 3
Number of clients: 3	
Max client requests: 1000
Timelimit: 15000ms 
```
Output file		: `baseline.txt` 

## Leadership changes
Leadership change was simulated in 2 ways – (i) crashing and (ii) slowing down leaders.
### Leadership changes with crashed leader
Aim			    : Trigger instant leadership change. A “stalemate” should also occur. 

Output file	: `crashed_leader.txt` 

Parameters:
```
Number of servers: 4 
```

How		: Go to `vote.ex` add `Process.exit(self, :kill)` in Line 101 after `become_leader` is called to kill leader servers once elected. Uncomment all IO.puts/.inspect in vote.ex to see the same outputs printed in the terminal.

### Leadership changes with slow leader
Aim			    : Observe leader stepdown. 

Output file	: `slow_leader.txt` 

How		      : Go to `appendenentries.ex`, in function `send_entries_to_followers`, add `Process.sleep(100)` in Line 14 to delay sending append entries request.

## Split votes
Aim			    : Re-elections should occur until a clear leader is elected.  

Output file	:  `split_votes.txt` 

How		      : Go to `configuration.ex`, set a short `election_timeout_range: 25..50ms` 

## Inconsistent Logs
Aim		      : Observe log repair. Server 1 cannot be leader as part of raft’s safety property. 

Output file : `log_repair.txt` 

How	        : Initialize logs at the start for each server such that they are inconsistent. Go to `server.ex`, add the following codes in Line 19 to initialize servers' logs. 

```
    s = if s.server_num != 1 do
      entry = %{1 => %{request: %{cid: {4, 1}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 1},
                2 => %{request: %{cid: {4, 2}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 2},
                3 => %{ request: %{cid: {4, 3},clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 3}}
      Log.merge_entries(s, entry)
    else
      entry = %{1 => %{request: %{cid: {4, 1}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 1},
                2 => %{request: %{cid: {4, 2}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 2},
                3 => %{request: %{cid: {5, 1}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 2},
                4 => %{request: %{cid: {6, 1}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 2},
                5 => %{request: %{cid: {6, 2}, clientP: 0, cmd: {:MOVE, 635, 99, 65}}, term: 2}}
      Log.merge_entries(s, entry)
    end 
```
*Note that clientP is set to 0 in the entries and hence the process will fail once it starts to send messages to clients. However, it is sufficient for the purposes of this experiment as we only wish to see how log repair and elections take place.

## Slow reply from followers
Aim				  : Observe system performance during slow follower replies. 

Output file : `slow_aereply_1.txt` and `slow_aereply_2.txt` 

How			    : Go to `appendenentries.ex`, use Process.sleep (80) before sending `:APPEND_ENTRIES_REPLY` (before Line 59 and 74).

Parameters:
```
- append_entries_timeout: 50 (in slow_aereply_1.txt)

- append_entries_timeout: 100 (in slow_aereply_2.txt)  
```

## Slow reply from leader to client
Aim		      : Observe how leaders handle repetitive client requests 

Output file : `slow_creply.txt` 

How	        : Go to `clientreq.ex`, use Process.sleep (30) before sending `:CLIENT_REPLY` in Line 58.

## Stress test
Aim		      : Model system performance under increasing load. 

Output file : `heavy_load.txt` and `heavy_load_300s.txt` 

How	        : Increment the number of servers from 5 to 10 in the  `Makefile`, handling 5 clients and 5000 request. Go to `client.ex`, use `Process.sleep(10)`  when receieving a `:NOT_LEADER` reply.

Parameters in `heavy_load.txt`:
```
- server                    : 10
- client                    : 5
- max_client_requests       : 5000,      
- client_request_interval   : 1,        
- client_reply_timeout      : 10 
```
Parameters in `heavy_load_300s.txt`:
```
- server                    : 10
- client                    : 5
- max_client_requests       : 5000,      
- client_request_interval   : 1,        
- client_reply_timeout      : 10 
- client_timelimit:         : 300_000
- TIMELIMIT                 : 300000	
```