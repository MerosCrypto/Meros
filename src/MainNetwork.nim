include MainLattice

#Create the Network.
network = newNetwork(NETWORK_ID, events)

#Start listening.
network.start(5132)

#Handle network events.
#Broadcast a message. This is used to send data out.
events.on(
    "network.broadcast",
    proc (msgType: MessageType, msg: string) =
        network.broadcast(
            newMessage(
                NETWORK_ID,
                PROTOCOL,
                msgType,
                msg
            )
        )
)
