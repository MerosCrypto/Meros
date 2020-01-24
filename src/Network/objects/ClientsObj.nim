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

#Client library.
import ../Client as ClientFile

#Sets standard lib.
import sets

#Async standard lib.
import asyncdispatch

#Clients object.
type Clients* = ref object
    #Used to provide each Client an unique ID.
    count*: int
    #Seq of every Client.
    clients*: seq[Client]
    #Set of the IPs of our peers.
    connected*: HashSet[string]

#Constructor.
proc newClients*(
    networkFunctions: NetworkLibFunctionBox,
    server: bool
): Clients {.forceCheck: [].} =
    var clients: Clients = Clients(
        #Starts at 1 because the local node is 0.
        count: 1,
        clients: newSeq[Client](),
        connected: initHashSet[string]()
    )
    result = clients

    #Add a repeating timer to remove inactive clients.
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
                while c < clients.clients.len:
                    #Close clients who have been inactive for half a minute.
                    if clients.clients[c].isClosed or (clients.clients[c].last + 30 <= getTime()):
                        clients.clients[c].close()
                        clients.connected.excl(clients.clients[c].ip)
                        clients.clients.del(c)
                        continue

                    #Reset noInc.
                    noInc = false

                    #Don't attempt to handshake with clients who we have a pending sync request with.
                    #This is because the sync response is just as valid and we've historically had issues with this.
                    #See https://github.com/MerosCrypto/Meros/issues/100.
                    if clients.clients[c].pendingSyncRequest == true:
                        return

                    #Handshake with clients who have been inactive for 20 seconds.
                    if clients.clients[c].last + 20 <= getTime():
                        try:
                            asyncCheck (
                                proc (): Future[void] {.forceCheck: [], async.} =
                                    #Don't handshake with clients who are syncing from us.
                                    #We aren't allowed to send the handshake message in this case.
                                    #The syncer must send the handshake.
                                    if clients.clients[c].remoteSync == true:
                                        return

                                    #Send the handshake.
                                    var tail: Hash[256]
                                    {.gcsafe.}:
                                        tail = networkFunctions.getTail()
                                    try:
                                        await clients.clients[c].send(
                                            newMessage(
                                                MessageType.Handshake,
                                                char(networkFunctions.getNetworkID()) &
                                                char(networkFunctions.getProtocol()) &
                                                (if server: char(1) else: char(0)) &
                                                tail.toString()
                                            )
                                        )
                                    except ClientError:
                                        clients.clients[c].close()
                                        clients.connected.excl(clients.clients[c].ip)
                                        clients.clients.del(c)
                                        noInc = true
                                    except Exception as e:
                                        doAssert(false, "Sending to a client threw an Exception despite catching all thrown Exceptions: " & e.msg)
                            )()
                        except Exception as e:
                            doAssert(false, "Calling a function to send a keep-alive to a client threw an Exception despite catching all thrown Exceptions: " & e.msg)

                    #Move on to the next client.
                    if not noInc:
                        inc(c)
        )
    except OSError as e:
        doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

#Add a new Client.
func add*(
    clients: Clients,
    client: Client
) {.forceCheck: [].} =
    #We do not inc(clients.total) here.
    #Clients calls it after Client creation.
    #Why? After we create a Client, but before we add it, we call handshake, which takes an unspecified amount of time.
    clients.clients.add(client)

    #Mark the Client as connected.
    clients.connected.incl(client.ip)

#Disconnect.
proc disconnect*(
    clients: Clients,
    id: int
) {.forceCheck: [].} =
    for i in 0 ..< clients.clients.len:
        if id == clients.clients[i].id:
            clients.clients[i].close()
            clients.connected.excl(clients.clients[i].ip)
            clients.clients.del(i)
            break

#Disconnects every client.
proc shutdown*(
    clients: Clients
) {.forceCheck: [].} =
    #Delete the first client until there is no first client.
    while clients.clients.len != 0:
        try:
            clients.clients[0].close()
        except Exception:
            discard
        clients.clients.delete(0)

    #Clear the connected set.
    #This should never be needed.
    #If we're shutting down the network, we're shutting down the node.
    #That said, it's better safe than sorry.
    clients.connected = initHashSet[string]()

#Getter.
func `[]`*(
    clients: Clients,
    id: int
): Client {.forceCheck: [
    IndexError
].} =
    for client in clients.clients:
        if client.id == id:
            return client
    raise newException(IndexError, "Couldn't find a Client with that ID.")

#Iterators.
iterator items*(
    clients: Clients
): Client {.forceCheck: [].} =
    for client in clients.clients.items():
        yield client

#Return all Clients where the peer isn't syncing in a way that allows disconnecting Clients.
iterator notSyncing*(
    clients: Clients
): Client {.forceCheck: [].} =
    if clients.clients.len != 0:
        var
            c: int = 0
            id: int

        while c < clients.clients.len - 1:
            if clients.clients[c].remoteSync:
                inc(c)
                continue

            id = clients.clients[c].id
            yield clients.clients[c]

            if clients.clients[c].id != id:
                continue
            inc(c)

        #Sort of the opposite of a do while.
        #Deleting the tail client crashed the if clients[c].id... check.
        #This knows it's running on the tail element and doesn't do any check on what happened.
        if not clients.clients[c].remoteSync:
            yield clients.clients[c]
