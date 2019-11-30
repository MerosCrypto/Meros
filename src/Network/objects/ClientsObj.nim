#Errors lib.
import ../../lib/Errors

#Client object.
import ClientObj

#sequtils standard lib.
import sequtils

#Networking standard lib.
import asyncnet

#Clients object.
type Clients* = ref object
    #Used to provide each Client an unique ID.
    count*: int
    #Seq of every Client.
    clients*: seq[Client]

#Constructor.
func newClients*(): Clients {.forceCheck: [].} =
    Clients(
        #Starts at 1 because the local node is 0.
        count: 1,
        clients: newSeq[Client]()
    )

#Add a new Client.
func add*(
    clients: Clients,
    client: Client
) {.forceCheck: [].} =
    #We do not inc(clients.total) here.
    #Clients calls it after Client creation.
    #Why? After we create a client, but before we add it, we call handshake, which takes an unspecified amount of time.
    clients.clients.add(client)

#Disconnect.
proc disconnect*(
    clients: Clients,
    id: int
) {.forceCheck: [].} =
    for i in 0 ..< clients.clients.len:
        if id == clients.clients[i].id:
            clients.clients[i].close()
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
