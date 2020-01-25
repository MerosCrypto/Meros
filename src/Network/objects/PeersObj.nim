#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Message object.
import MessageObj

#Network Function Box.
import NetworkLibFunctionBoxObj

#Peer library.
import ../Peer as PeerFile

#Sets standard lib.
import sets

#Async standard lib.
import asyncdispatch

#Peers object.
type Peers* = ref object
    #Used to provide each Peer an unique ID.
    count*: int
    #Seq of every Peer.
    peers*: seq[Peer]
    #Set of the IPs of our peers.
    connected*: HashSet[string]

#Constructor.
proc newPeers*(
    networkFunctions: NetworkLibFunctionBox,
    server: bool
): Peers {.forceCheck: [].} =
    var peers: Peers = Peers(
        #Starts at 1 because the local node is 0.
        count: 1,
        peers: newSeq[Peer](),
        connected: initHashSet[string]()
    )
    result = peers

    #Add a repeating timer to remove inactive Peers.
    try:
        addTimer(
            7000,
            false,
            proc (
                fd: AsyncFD
            ): bool {.forceCheck: [].} =
                var
                    c: int = 0
                    noInc: bool
                while c < peers.peers.len:
                    #Close Peers who have been inactive for half a minute.
                    if peers.peers[c].isClosed or (peers.peers[c].last + 30 <= getTime()):
                        peers.peers[c].close()
                        peers.connected.excl(peers.peers[c].ip)
                        peers.peers.del(c)
                        continue

                    #Handshake with Peers who have been inactive for 20 seconds.
                    if peers.peers[c].last + 20 <= getTime():
                        try:
                            asyncCheck (
                                proc (
                                    id: int
                                ): Future[void] {.forceCheck: [], async.} =
                                    #Send the handshake.
                                    var tail: Hash[256]
                                    {.gcsafe.}:
                                        tail = networkFunctions.getTail()
                                    try:
                                        await peers.peers[c].send(
                                            newMessage(
                                                MessageType.Handshake,
                                                char(networkFunctions.getNetworkID()) &
                                                char(networkFunctions.getProtocol()) &
                                                networkFunctions.getPort().toBinary() &
                                                (if server: char(1) else: char(0)) &
                                                tail.toString()
                                            )
                                        )
                                    except PeerError:
                                        peers.peers[c].close()
                                    except Exception as e:
                                        doAssert(false, "Sending to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)
                            )(peers.peers[c].id)
                        except Exception as e:
                            doAssert(false, "Calling a function to send a keep-alive to a Peer threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    #Move on to the next Peer.
                    inc(c)
        )
    except OSError as e:
        doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

#Add a new Peer.
func add*(
    peers: Peers,
    peer: Peer
) {.forceCheck: [].} =
    #We do not inc(peers.total) here.
    #Peers calls it after Peer creation.
    #Why? After we create a Peer, but before we add it, we call handshake, which takes an unspecified amount of time.
    peers.peers.add(peer)

    #Mark the Peer as connected.
    peers.connected.incl(peer.ip)

#Disconnect.
proc disconnect*(
    peers: Peers,
    id: int
) {.forceCheck: [].} =
    for i in 0 ..< peers.peers.len:
        if id == peers.peers[i].id:
            peers.peers[i].close()
            peers.connected.excl(peers.peers[i].ip)
            peers.peers.del(i)
            break

#Disconnects every Peer.
proc shutdown*(
    peers: Peers
) {.forceCheck: [].} =
    #Delete the first Peer until there is no first Peer.
    while peers.peers.len != 0:
        try:
            peers.peers[0].close()
        except Exception:
            discard
        peers.peers.delete(0)

#Getter.
func `[]`*(
    peers: Peers,
    id: int
): Peer {.forceCheck: [
    IndexError
].} =
    for peer in peers.peers:
        if peer.id == id:
            return peer
    raise newException(IndexError, "Couldn't find a Peer with that ID.")

#Iterators.
iterator items*(
    peers: Peers
): Peer {.forceCheck: [].} =
    for peer in peers.peers.items():
        yield peer

#Return all Peers where the peer isn't syncing in a way that allows disconnecting Peers.
iterator notSyncing*(
    peers: Peers
): Peer {.forceCheck: [].} =
    if peers.peers.len != 0:
        var
            c: int = 0
            id: int

        while c < peers.peers.len - 1:
            if peers.peers[c].remoteSync:
                inc(c)
                continue

            id = peers.peers[c].id
            yield peers.peers[c]

            if peers.peers[c].id != id:
                continue
            inc(c)

        #Sort of the opposite of a do while.
        #Deleting the tail peer crashed the if peers[c].id... check.
        #This knows it's running on the tail element and doesn't do any check on what happened.
        if not peers.peers[c].remoteSync:
            yield peers.peers[c]
