#Main Function Box.
import ../../MainFunctionBox

#Import the Clients object.
import ClientsObj

#Network Function Box.
import NetworkFunctionBox

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
        networkFunctions* {.final.}: NetworkFunctionBox
        #Main Function Box.
        mainFunctions* {.final.}: MainFunctionBox

#Constructor.
func newNetworkObj*(
    id: uint,
    protocol: uint,
    clients: Clients,
    server: AsyncSocket,
    networkFunctions: NetworkFunctionBox,
    mainFunctions: MainFunctionBox
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
