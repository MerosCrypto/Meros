import locks
import tables

import chronos

import ../../lib/[Errors, Util, Hash]

import ../../objects/GlobalFunctionBoxObj

import MessageObj
import SocketObj

import LiveManagerObj
import SyncManagerObj

import ../FileLimitTracker

import ../Peer as PeerFile

import ../Serialize/SerializeCommon

#Masks used to lock an IP while we modify it.
const
  CLIENT_IP_LOCK: byte = 0b1
  LIVE_IP_LOCK*: byte = 0b10
  SYNC_IP_LOCK*: byte = 0b100

type Network* = ref object
  functions*: GlobalFunctionBox

  #[
  File limit tracker. Used to ensure we don't trigger ulimit, causing undefined behavior.
  It shouldn't actually be undefined; just behavior we don't account for and handle.
  This causes undefined behavior in the node.
  Also allows us to refer clients to other peers when we're near our limit.
  ]#
  fileTracker*: FileLimitTracker

  #[
  Lock for the IP masks.
  This is required before the byte locks are modified.
  Then when the byte locks are modified, safe modification of the Peers is possible.
  ]#
  ipLock: Lock
  masks: Table[string, byte]

  #Used to provide each Peer an unique ID.
  #peers.len wouldn't work due to peers disconnecting over time.
  count*: int

  peers*: TableRef[int, Peer]

  #[
  Dedicated seq exists, instead of using peers.items or a HashSet, so we can mutate the ID list as we iterate.
  We could use peers.items, combined with a queue to delete after the fact, as that may be cleaner.
  ]#
  ids*: seq[int]

  #Tables pointing from an IP to the peer ID. Exists for both live and sync.
  live*: Table[string, int]
  sync*: Table[string, int]

  #[
  Last local peer.
  We support unlimited connections from 127.0.0.1.
  That said, we still attempt to link live/sync sockets.
  This is an imperfect solution which allows that.
  When a new Sync socket is added, if this Peer is missing the Live socket, they're linked.
  The same applies when a Live socket is added.
  ]#
  lastLocalPeer*: Peer

  server*: StreamServer

  liveManager*: LiveManager
  syncManager*: SyncManager

proc newNetwork*(
  protocol: uint,
  networkID: uint,
  port: int,
  functions: GlobalFunctionBox
): Network {.forceCheck: [].} =
  #This is set to network, instead of result, so the functions defined inside this function have access.
  var network: Network = Network(
    functions: functions,

    fileTracker: newFileLimitTracker(),

    masks: initTable[string, byte](),

    #Starts at 1 because the local node is 0.
    count: 1,
    peers: newTable[int, Peer](),
    ids: @[],
    live: initTable[string, int](),
    sync: initTable[string, int]()
  )
  initLock(network.ipLocK)

  network.liveManager = newLiveManager(
    protocol,
    networkID,
    port,
    network.peers,
    functions
  )
  network.syncManager = newSyncManager(
    protocol,
    networkID,
    port,
    network.peers,
    functions
  )

  #Set result to network so it's returned.
  result = network

  #Add a repeating timer to remove inactive Peers.
  var removeInactiveTimer: TimerCallback = nil
  proc removeInactive(
    data: pointer = nil
  ) {.gcsafe, forceCheck: [].} =
    var
      p: int = 0
      peer: Peer
    while p < network.ids.len:
      #Grab the peer.
      try:
        peer = network.peers[network.ids[p]]
      except KeyError as e:
        #Not a panic due to GC safety rules.
        panic("Failed to get a peer we have an ID for: " & e.msg)

      #Exclude closed sockets from live/sync.
      if peer.live.closed:
        network.live.del(peer.ip)
      if peer.sync.closed:
        network.sync.del(peer.ip)

      #Close Peers who have been inactive for half a minute.
      if peer.isClosed or (peer.last + 30 <= getTime()):
        peer.close("Peer is closed/inactive.")
        network.live.del(peer.ip)
        network.sync.del(peer.ip)
        network.peers.del(network.ids[p])
        network.ids.del(p)
        continue

      #Handshake with Peers who have been inactive for 20 seconds.
      if peer.last + 20 <= getTime():
        #Send the Handshake.
        try:
          if not peer.live.closed:
            asyncCheck peer.sendLive(
              newMessage(
                MessageType.Handshake,
                char(network.liveManager.protocol) &
                char(network.liveManager.network) &
                char(network.liveManager.services) &
                network.liveManager.port.toBinary(PORT_LEN) &
                network.functions.merit.getTail().serialize()
              ),
              true
            )
          else:
            asyncCheck peer.sendSync(
              newMessage(
                MessageType.Syncing,
                char(network.syncManager.protocol) &
                char(network.syncManager.network) &
                char(network.syncManager.services) &
                network.syncManager.port.toBinary(PORT_LEN) &
                network.functions.merit.getTail().serialize()
              ),
              true
            )
        except SocketError:
          discard
        except Exception as e:
          panic("Sending to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

      #Move on to the next Peer.
      inc(p)

    #Clear the existing timer.
    if not removeInactiveTimer.isNil:
      clearTimer(removeInactiveTimer)

    #Register the timer again.
    try:
      removeInactiveTimer = setTimer(Moment.fromNow(seconds(10)), removeInactive)
    #OSError/IOSelectorsException. The latter doesn't appear on Linux yet does appear on macOS.
    except Exception as e:
      panic("Setting a timer to remove inactive peers failed: " & e.msg)

  #Call removeInactive so it registers the timer.
  removeInactive()

  #Add a repeating timer to update the amount of open files.
  var updateFileTrackerTimer: TimerCallback = nil
  proc updateFileTracker(
    data: pointer = nil
  ) {.gcsafe, forceCheck: [].} =
    network.fileTracker.update()
    if not updateFileTrackerTimer.isNil:
      clearTimer(updateFileTrackerTimer)
    try:
      updateFileTrackerTimer = setTimer(Moment.fromNow(minutes(1)), updateFileTracker)
    except Exception as e:
      panic("Setting a timer to update the amount of open files failed: " & e.msg)
  updateFileTracker()

#Lock an IP so we can modify its Peer.
proc lockIP*(
  network: Network,
  ip: string,
  mask: byte = CLIENT_IP_LOCK
): Future[bool] {.forceCheck: [], async.} =
  #Acquire the IP lock so we can edit the locks in the first place.
  while true:
    if tryAcquire(network.ipLock):
      break

    try:
      await sleepAsync(milliseconds(10))
    except Exception as e:
      panic("Failed to complete an async sleep: " & e.msg)

  #Create the mask if there isn't one.
  if not network.masks.hasKey(ip):
    network.masks[ip] = mask
    result = true
  #If we're forming a client connection, and either already have one or they're already connecting to us, return false.
  elif mask == CLIENT_IP_LOCK:
    result = false
  else:
    var currMask: byte
    try:
      currMask = network.masks[ip]
    except KeyError as e:
      panic("Couldn't get an IP's mask despite confirming the key exists: " & e.msg)

    #If we're currently attempting a client connection, or attempting to handle this type of server connection, set the result to false.
    if (
      (currMask == CLIENT_IP_LOCK) or
      ((currMask and mask) == mask)
    ):
      result = false
    else:
      #Add the mask and set the result to true.
      network.masks[ip] = currMask or mask
      result = true

  #Release the IP lock.
  release(network.ipLock)

proc unlockIP*(
  network: Network,
  ip: string,
  mask: byte = CLIENT_IP_LOCK
) {.forceCheck: [], async.} =
  #Acquire the IP lock.
  while true:
    if tryAcquire(network.ipLock):
      break

    try:
      await sleepAsync(milliseconds(10))
    except Exception as e:
      panic("Failed to complete an async sleep: " & e.msg)

  #Remove the bitmask.
  var newMask: byte
  try:
    newMask = network.masks[ip] and (not mask)
  except KeyError as e:
    panic("Attempted to unlock an IP that was never locked: " & e.msg)

  #Delete the mask entirely if it's no longer used.
  if newMask == 0:
    network.masks.del(ip)
  else:
    network.masks[ip] = newMask

  #Release the IP lock.
  release(network.ipLock)

proc add*(
  network: Network,
  peer: Peer
) {.forceCheck: [].} =
  peer.id = network.count
  inc(network.count)

  network.peers[peer.id] = peer
  network.ids.add(peer.id)

  if peer.ip.len == 6:
    network.lastLocalPeer = peer

proc disconnect*(
  network: Network,
  peer: Peer
) {.forceCheck: [].} =
  #Close the peer and delete it from the tables.
  peer.close("Ordered to disconnect the peer.")
  network.peers.del(peer.id)
  network.live.del(peer.ip)
  network.sync.del(peer.ip)

  #Delete its ID.
  for p in 0 ..< network.ids.len:
    if peer.id == network.ids[p]:
      network.ids.del(p)
      break

#Disconnect every Peer.
proc shutdown*(
  network: Network
) {.forceCheck: [].} =
  #Delete the first Peer until there is no first Peer.
  while network.ids.len != 0:
    try:
      network.peers[network.ids[0]].close("Shutting down.")
    except Exception:
      discard

    network.peers.del(network.ids[0])
    network.ids.del(0)
