#Errors lib.
import ../lib/Errors

#Util lib.
import ../lib/Util

#Message/Client/Clients/Network objects.
import objects/MessageObj
import objects/ClientObj
import objects/ClientsObj
import objects/NetworkObj
#Export the Message, Clients, and Network objects.
export MessageObj
export ClientsObj
export NetworkObj

#Network Function Box.
import objects/NetworkFunctionBox

#Networking standard libs.
import asyncdispatch, asyncnet

#Listen on a port.
proc listen*(network: Network, port: uint) {.async.} =
    #Start listening.
    network.server.setSockOpt(OptReuseAddr, true)
    network.server.bindAddr(Port(port))
    network.server.listen()

    #Accept new connections infinitely.
    while not network.server.isClosed():
        #This is in a try/catch since ending the server while accepting a new Client will throw an Exception.
        try:
            #Tell the Network lib of the new client.
            discard await network.server.acceptAddr()
        except:
            continue
