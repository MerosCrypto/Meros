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
        id* {.final.}: uint
        #Protocol version.
        protocol* {.final.}: uint
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
    id: uint,
    protocol: uint,
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
