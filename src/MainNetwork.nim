include MainPersonal

proc mainNetwork() {.raises: [
    SocketError
].} =
    {.gcsafe.}:
        #Create the Network..
        network = newNetwork(NETWORK_ID, NETWORK_PROTOCOL, functions)

        #Start listening.
        try:
            asyncCheck network.listen(config)
        except:
            raise newException(SocketError, "Couldn't listen on our server socket.")

        #Handle network events.
        #Connect to another node.
        functions.network.connect = proc (
            ip: string,
            port: int
        ): Future[bool] {.async.} =
            try:
                await network.connect(ip, port)
                result = true
            except:
                result = false

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
