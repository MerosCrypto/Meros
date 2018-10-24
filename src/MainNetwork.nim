include MainLattice

proc mainNetwork*() {.raises: [
    AsyncError,
    SocketError
].} =
    {.gcsafe.}:
        #Create the Network..
        network = newNetwork(NETWORK_ID, events)

        #Start listening.
        network.start(NETWORK_PORT)

        #Handle network events.
        #Connect to another node.
        events.on(
            "network.connect",
            proc (ip: string, port: int): bool {.raises: [].} =
                try:
                    asyncCheck network.connect(ip, port)
                    result = true
                except:
                    result = false
        )

        #Broadcast a message. This is used to send data out.
        events.on(
            "network.broadcast",
            proc (msgType: MessageType, msg: string) {.raises: [AsyncError, SocketError].} =
                network.broadcast(
                    newMessage(
                        NETWORK_ID,
                        NETWORK_PROTOCOL,
                        msgType,
                        msg
                    )
                )
        )
