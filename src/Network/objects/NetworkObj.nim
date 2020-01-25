#Errors lib.
import ../../lib/Errors

#Global Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Import the Peers object.
import PeersObj

#Network Function Box.
import NetworkLibFunctionBoxObj

#Asyncnet standard lib.
import asyncnet

type Network* = ref object
    #Network ID.
    id*: int
    #Protocol version.
    protocol*: int
    #Server port.
    port*: int

    #Peers.
    peers*: Peers
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
    port: int,
    networkFunctions: NetworkLibFunctionBox,
    mainFunctions: GlobalFunctionBox
): Network {.inline, forceCheck: [].} =
    Network(
        id: id,
        protocol: protocol,
        port: port,

        peers: newPeers(networkFunctions, server),
        networkFunctions: networkFunctions,
        mainFunctions: mainFunctions
    )
