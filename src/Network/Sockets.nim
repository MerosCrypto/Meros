#Import the Message object.
import Sockets/objects/MessageObj

#Import the socket sublibraries.
import Sockets/Server as ServerFile
import Sockets/Client

#Events library.
import ec_events

#Async standand lib.
import asyncdispatch

const
    #Minimum supported protocol.
    MIN_PROTOCOL: int = 0
    #Maximum supported protocol.
    MAX_PROTOCOL: int = 0

var
    #Network ID.
    network: int = 0

    #Socket Event Emitter for the sublibraries.
    socketEvents: EventEmitter = newEventEmitter()
    #Node Event Emitter for the node.
    nodeEvents: EventEmitter

    #Server.
    server: Server = newServer(socketEvents)

#On a new message...
socketEvents.on(
    "new",
    proc (msgArg: Message) =
        #Extract the message.
        var msg: string = msgArg.getMessage()

        #Validate the network ID.
        if ord(msg[0]) != network:
            server.disconnect(msgArg)

        #Validate the protocol.
        if ord(msg[1]) < MIN_PROTOCOL:
            return
        if ord(msg[1]) > MAX_PROTOCOL:
            return

        #Verify the message length.
        if ord(msg[3]) + 4 != msg.len:
            return

        #Switch based off the message type.
        case ord(msg[2]):
            else:
                discard
)

asyncCheck server.listen()
