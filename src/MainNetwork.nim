include MainPersonal

proc mainNetwork() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Network..
        network = newNetwork(NETWORK_ID, NETWORK_PROTOCOL, functions)

        #Start listening.
        try:
            asyncCheck network.listen(config)
        except Exception:
            discard

        #Handle network events.
        #Connect to another node.
        functions.network.connect = proc (
            ip: string,
            port: int
        ) {.async.} =
            await network.connect(ip, port)

        #Broadcast a message.
        functions.network.broadcast = proc (
            msgType: MessageType,
            msg: string
        ) {.async.} =
            await network.broadcast(
                newMessage(
                    msgType,
                    msg
                )
            )
