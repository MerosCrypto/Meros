#Errors lib.
import ../../lib/Errors

#Global Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Import the Clients object.
import ClientsObj

#Network Function Box.
import NetworkLibFunctionBoxObj

#Asyncnet standard lib.
import asyncnet

type Network* = ref object
    #Network ID.
    id*: int
    #Protocol version.
    protocol*: int
    #Clients.
    clients*: Clients
    #Server.
    server*: AsyncSocket
    #Network Function Box.
    networkFunctions*: NetworkLibFunctionBox
    #Global Function Box.
    mainFunctions*: GlobalFunctionBox

#Constructor.
proc newNetworkObj*(
    id: int,
    protocol: int,
    server: bool,
    networkFunctions: NetworkLibFunctionBox,
    mainFunctions: GlobalFunctionBox
): Network {.inline, forceCheck: [].} =
    Network(
        id: id,
        protocol: protocol,
        clients: newClients(networkFunctions, server),
        networkFunctions: networkFunctions,
        mainFunctions: mainFunctions
    )
