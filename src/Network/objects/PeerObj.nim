import locks
import math
import random
import tables

import ../../lib/[Errors, Util]

import SocketObj

#[
Handshakes include service bits, which are used to declare supported services.
Right now, these are just used to say if a peer is accepting connections as a server.
In the future, it can be used for protocol extensions which allow optimizations without a hardfork.
Or building a second layer communication network on top of the existing Meros network, through nodes who allow it.
Adding a service that is greater than, or equal to, 128, requires using VarInt serialization.

Ever since https://github.com/MerosCrypto/Meros/issues/270, this isn't true.
This commentary about service bits is left as a generic explainer.
]#
#const SERVER_SERVICE*: uint = 0b1

type Peer* = ref object
  id*: int
  ip*: string

  #Whether or not they can be connected to as a server.
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
  #If the requested amount of peers is max(sqrt(peers.len), X) or Y.
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
    let req: int = max(int(ceil(math.sqrt(float(peers.len)))), 4)
  else:
    #Use a higher value if we don't have sqrt available to raise the amount.
    #As of the time of this commit, this is only used for peer finding.
    let req: int = 6

  while result.len > req:
    result.del(rand(high(result)))
