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
    var toDelete: int
    for i, client in clients.clients:
        if client.id == id:
            client.close()
            toDelete = i
            break
    clients.clients.delete(toDelete)

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

#Iterator.
iterator items*(
    clients: Clients
): Client {.forceCheck: [].} =
    for client in clients.clients.items():
        yield client
