#Global Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Import the Clients object.
import ClientsObj

#Network Function Box.
import NetworkLibFunctionBoxObj

#finals lib.
import finals

#Asyncnet standard lib.
import asyncnet

finalsd:
    type Network* = ref object of RootObj
        #Network ID.
        id* {.final.}: int
        #Protocol version.
        protocol* {.final.}: int
        #Clients.
        clients* {.final.}: Clients
        #Server.
        server* {.final.}: AsyncSocket
        #Network Function Box.
        networkFunctions* {.final.}: NetworkLibFunctionBox
        #Global Function Box.
        mainFunctions* {.final.}: GlobalFunctionBox

#Constructor.
func newNetworkObj*(
    id: int,
    protocol: int,
    clients: Clients,
    server: AsyncSocket,
    networkFunctions: NetworkLibFunctionBox,
    mainFunctions: GlobalFunctionBox
): Network {.raises: [].} =
    result = Network(
        id: id,
        protocol: protocol,
        clients: clients,
        server: server,
        networkFunctions: networkFunctions,
        mainFunctions: mainFunctions
    )
    result.ffinalizeID()
    result.ffinalizeProtocol()
    result.ffinalizeClients()
    result.ffinalizeServer()
    result.ffinalizeNetworkFunctions()
    result.ffinalizeMainFunctions()
