#Send libs.
import ../Database/Lattice/Send
import Serialize/ParseSend

#Receive libs.
import ../Database/Lattice/Receive
import Serialize/ParseReceive

#Message object.
import objects/MessageObj

#Socket sublibs.
import Server
import Client

#Network object.
import objects/NetworkObj
export NetworkObj

#Events lib.
import ec_events

#SetOnce lib.
import SetOnce

#Async standard lib.
import asyncdispatch

const
    #Minimum supported protocol.
    MIN_PROTOCOL: int = 0
    #Maximum supported protocol.
    MAX_PROTOCOL: int = 0

#Constructor.
proc newNetwork*(id: int, nodeEvents: EventEmitter): Network {.raises: [OSError, Exception].} =
    #Event emitter for the socket sublibraries.
    var events: EventEmitter = newEventEmitter()

    #Create the Network object.
    result = newNetworkObj(
        id,
        events,
        newServer(events),
        nodeEvents
    )

    #On a new message...
    events.on(
        "new",
        proc (msg: Message): Future[bool] {.async.} =
            #Set the result to true.
            result = true

            #Validate the network ID.
            if msg.network != id:
                return false

            #Validate the protocol.
            if msg.version < MIN_PROTOCOL:
                return false
            if msg.version > MAX_PROTOCOL:
                return false

            #Verify the message length.
            if ord(msg.header[3]) != msg.message.len:
                return false

            #Switch based off the message type (in a try to handle invalid messages).
            try:
                case msg.content.toValue():
                    of MessageType.Send:
                        nodeEvents.get(
                            proc (send: Send),
                            "send"
                        )(
                            msg.message.parseSend()
                        )
                    of MessageType.Receive:
                        nodeEvents.get(
                            proc (recv: Receive),
                            "recv"
                        )(
                            msg.message.parseReceive()
                        )
                    of MessageType.Data:
                        discard
                    of MessageType.Verification:
                        discard
                    of MessageType.MeritRemoval:
                        discard
            except:
                echo "Invalid Message."
    )

#Start listening.
proc listen*(network: Network, port: int = 5132) =
    #Start the server.
    asyncCheck network.server.listen(port)
