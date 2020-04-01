include MainPersonal

proc mainNetwork(
    params: ChainParams,
    config: Config,
    functions: GlobalFunctionBox,
    network: ref Network
) {.forceCheck: [].} =
    #Create the Network..
    network[] = newNetwork(
        params.NETWORK_PROTOCOL,
        params.NETWORK_ID,
        config.tcpPort,
        functions
    )

    #Start listening, if we're supposed to.
    if config.server:
        try:
            asyncCheck network[].listen()
        except Exception:
            discard

    #Handle network events.
    #Connect to another node.
    functions.network.connect = proc (
        ip: string,
        port: int
    ) {.forceCheck: [], async.} =
        try:
            await network[].connect(ip, port)
        except Exception as e:
            panic("Couldn't connect to another node due to an Exception thrown by async: " & e.msg)

    #Get the peers we're connected to.
    functions.network.getPeers = proc (): seq[Peer] {.forceCheck: [].} =
        network.peers.getPeers(network.peers.len)

    #Broadcast a message.
    functions.network.broadcast = proc (
        msgType: MessageType,
        msg: string
    ) {.forceCheck: [].} =
        try:
            asyncCheck network[].broadcast(
                newMessage(
                    msgType,
                    msg
                )
            )
        except Exception as e:
            panic("Network.broadcast threw an Exception despite not naturally throwing any: " & e.msg)

    #Look for new peers if we don't have enough already.
    proc requestPeersRegularly(
        data: pointer = nil
    ) {.gcsafe, forceCheck: [].} =
        proc requestPeers() {.forceCheck: [], async.} =
            if network.peers.len >= 8:
                return

            var peers: seq[tuple[ip: string, port: int]]
            try:
                peers = await syncAwait network.syncManager.syncPeers(params.SEEDS)
            except Exception as e:
                panic("requestPeers threw an Exception despite not actually throwing any: " & e.msg)

            for peer in peers:
                try:
                    await network[].connect(peer.ip, peer.port)
                except Exception as e:
                    panic("Couldn't connect to another node due to an Exception thrown by async: " & e.msg)
        try:
            asyncCheck requestPeers()
        except Exception as e:
            panic("Couldn't request peers despite requesting peers not raising anything: " & e.msg)

        #Add a new timer to look for peers since this one expired.
        try:
            discard setTimer(Moment.fromNow(minutes(2)), requestPeersRegularly)
        except OSError as e:
            panic("Couldn't re-set a timer to request peers: " & e.msg)

    #Also request peers now.
    requestPeersRegularly()
