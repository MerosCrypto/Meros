include MainPersonal

proc mainNetwork() {.raises: [
    AsyncError,
    SocketError
].} =
    {.gcsafe.}:
        #Create the Network..
        network = newNetwork(NETWORK_ID, NETWORK_PROTOCOL, events)

        #Start listening.
        network.start(NETWORK_PORT)

        #Handle network events.
        #Connect to another node.
        try:
            events.on(
                "network.connect",
                proc (ip: string, port: uint): Future[bool] {.async.} =
                    try:
                        await network.connect(ip, port)
                        result = true
                    except:
                        result = false
            )
        except:
            raise newException(AsyncError, "Couldn't add an Async proc to the EventEmitter.")

        #Broadcast a message. This is used to send data out.
        events.on(
            "network.broadcast",
            proc (msgType: MessageType, msg: string) {.raises: [AsyncError].} =
                network.broadcast(
                    newMessage(
                        msgType,
                        msg
                    )
                )
        )
