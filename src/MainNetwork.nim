include MainPersonal

proc mainNetwork() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Network..
        network = newNetwork(
            params.NETWORK_ID,
            params.NETWORK_PROTOCOL,
            functions
        )

        #Start listening, if we're supposed to.
        if config.server:
            try:
                asyncCheck network.listen(config)
            except Exception:
                discard

        #Handle network events.
        #Connect to another node.
        functions.network.connect = proc (
            ip: string,
            port: int
        ) {.forceCheck: [
            ClientError
        ], async.} =
            try:
                await network.connect(ip, port)
            except ClientError as e:
                fcRaise e
            except Exception as e:
                doAssert(false, "Couldn't connect to another node due to an exception thrown by async: " & e.msg)

        #Broadcast a message.
        functions.network.broadcast = proc (
            msgType: MessageType,
            msg: string
        ) {.forceCheck: [].} =
            try:
                asyncCheck network.broadcast(
                    newMessage(
                        msgType,
                        msg
                    )
                )
            except Exception as e:
                doAssert(false, "Network.broadcast threw an Exception despite not naturally throwing any: " & e.msg)
