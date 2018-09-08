#Import the Message object.
import objects/MessageObj

#Import the socket sublibraries.
import Server
import Client

#Import the Network object.
import objects/NetworkObj

#Events library.
import ec_events

#Async standand lib.
import asyncdispatch

const
    #Minimum supported protocol.
    MIN_PROTOCOL: int = 0
    #Maximum supported protocol.
    MAX_PROTOCOL: int = 0

proc newNetwork*(id: int): Network =
    #Event emitter for the socket sublibraries.
    var events: EventEmitter = newEventEmitter()

    #On a new message...
    events.on(
        "new",
        proc (msg: Message): Future[bool] {.async.} =
            #Set the result to true.
            result = true

            #Validate the network ID.
            if msg.getNetwork() != id:
                return false

            #Validate the protocol.
            if msg.getVersion() < MIN_PROTOCOL:
                return false
            if msg.getVersion() > MAX_PROTOCOL:
                return false

            #Verify the message length.
            if ord(msg.getHeader()[3]) != msg.getMessage().len:
                return false

            #Switch based off the message type.
            case msg.getContent():
                else:
                    discard
    )

    #Create the Network object.
    result = newNetworkObj(
        id,
        events,
        newServer(events)
    )

    #Start the server.
    asyncCheck result.getServer().listen()
