include MainPersonal

proc mainNetwork() {.raises: [
    AsyncError,
    SocketError
].} =
    {.gcsafe.}:
        discard """
        #Create the Network..
        network = newNetwork(NETWORK_ID, NETWORK_PROTOCOL, events)

        #Start listening.
        network.start(NETWORK_PORT)

        #Handle network events.
        #Connect to another node.
        functions.network.connect = proc (
            ip: string,
            port: uint
        ): Future[bool] {.async.} =
            try:
                await network.connect(ip, port)
                result = true
            except:
                result = false

        #Broadcast a message. This is used to send data out.
        functions.network.broadcast = proc (
            msgType: MessageType,
            msg: string
        ) {.raises: [AsyncError].} =
            network.broadcast(
                newMessage(
                    msgType,
                    msg
                )
            )
        """

        #Provide fake functions for now,
        functions.network.connect = proc (
            ip: string,
            port: uint
        ): Future[bool] {.async.} =
            echo "Fake connect."

        functions.network.broadcast = proc (
            msgType: MessageType,
            msg: string
        ) {.raises: [AsyncError].} =
            echo "Fake broadcast."
