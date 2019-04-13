#Errors lib.
import ../../lib/Errors

#Client object.
import ClientObj

#sequtils standard lib.
import sequtils

#Networking standard lib.
import asyncnet

#Clients object.
type Clients* = ref object of RootObj
    #Used to provide each Client an unique ID.
    count*: int
    #Seq of every Client.
    clients*: seq[Client]

#Constructor.
func newClients*(): Clients {.raises: [].} =
    Clients(
        #Starts at 1 because the local node is 0.
        count: 1,
        clients: newSeq[Client]()
    )

#Add a new Client.
proc add*(clients: Clients, client: Client) {.raises: [].} =
    #We do not inc(clients.total) here.
    #Clients calls it after Client creation.
    #Why? After we create a client, but before we add it, we call handshake, which takes an unspecified amount of time.
    clients.clients.add(client)

#Disconnect.
proc disconnect*(clients: Clients, id: int) {.raises: [].} =
    for i, client in clients.clients:
        if client.id == id:
            try:
                client.socket.close()
            except:
                #If we can't close the Client, we should still delete it from Clients.
                discard
            clients.clients.delete(i)

#Disconnects every client.
proc shutdown*(clients: Clients) {.raises: [].} =
    for client in clients.clients:
        try:
            client.socket.close()
        except:
            discard
        #Delete the first client. Since we iterate from start to finish, and always delete the client...
        clients.clients.delete(0)

#Getter.
func `[]`*(clients: Clients, id: int): Client {.raises: [].} =
    for client in clients.clients:
        if client.id == id:
            return client

#Iterator.
iterator items*(clients: Clients): Client {.raises: [].} =
    for client in clients.clients:
        yield client
