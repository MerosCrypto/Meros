include MainLattice

#Create the Network.
network = newNetwork(NETWORK_ID, events)

#Start listening.
network.start(NETWORK_PORT)

#Handle network events.
#Broadcast a message. This is used to send data out.
events.on(
    "network.broadcast",
    proc (msgType: MessageType, msg: string) {.raises: [AsyncError, SocketError].}=
        network.broadcast(
            newMessage(
                NETWORK_ID,
                NETWORK_PROTOCOL,
                msgType,
                msg
            )
        )
)
