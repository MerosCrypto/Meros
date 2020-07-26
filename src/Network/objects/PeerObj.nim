import locks
import math
import random
import tables

import ../../lib/[Errors, Util]

import SocketObj

#[
Handshakes include service bytes, which are used to declare supported... services.
Right now, these are just used to say a peer is accepting connections as a server.
In the future, it can be used for protocol extensions which allow optimizations without a hardfork.
Or building a second layer communication network on top of the existing Meros network, through nodes who allow it.
]#
const SERVER_SERVICE*: byte = 0b10000000

type Peer* = ref object
  id*: int
  ip*: string

  #Whether or not the server service bit has been set.
  server*: bool
  #Port of their server, if one exists.
  port*: int

  #Time of their last message.
  last*: uint32

  #Lock used to append to the pending sync requests.
  syncLock*: Lock
  #Pending sync requests. The int refers to an ID in the SyncManager's table.
  #This seq is used to handle sync responses from this peer, specifically.
  #Verifying they're ordered and knowing how to hand them off.
  requests*: seq[int]

  live*: Socket
  sync*: Socket

proc newPeer*(
  ip: string,
): Peer {.forceCheck: [].} =
  result = Peer(
    ip: ip,
    last: getTime()
  )
  initLock(result.syncLock)

#Check if a Peer is closed.
func isClosed*(
  peer: Peer
): bool {.inline, forceCheck: [].} =
  peer.live.closed and peer.sync.closed

proc close*(
  peer: Peer,
  reason: string
) {.forceCheck: [].} =
  peer.live.safeClose("")
  peer.sync.safeClose("")

  logDebug "Closing peer", id = peer.id, reason = reason

#Get random peers which meet the specified criteria.
proc getPeers*(
  peers: TableRef[int, Peer],
  #Peer to skip. Used when rebroadcasting and we don't want to rebroadcast back to the source.
  skip: int = 0,
  #Only get peers with a live socket.
  live: bool = false,
  #Only get peers who are servers. Used when asked for peers to connect to.
  server: bool = false,
  #If the requested amount of peers is min(sqrt(peers.len), X) or min(peers.len, Y).
  sqrt: static[bool] = true
): seq[Peer] {.forceCheck: [].} =
  if peers.len == 0:
    return

  for peer in peers.values():
    if (
      (server and (not peer.server)) or
      (live and peer.live.closed) or
      (peer.id == skip)
    ):
      continue
    result.add(peer)

  when sqrt:
    var req: int = max(
      min(result.len, 3),
      int(ceil(math.sqrt(float(peers.len))))
    )
  else:
    #Use a higher minimum if we don't have sqrt available to raise the amount.
    #As of the time of this commit, this is only used for peer finding.
    #4 is a reasonable number for that, but in the future, we should consider raising it further.
    #4 only remains reasonable when the network is samll.
    var req: int = min(result.len, 4)

  while result.len > req:
    result.del(rand(high(result)))
