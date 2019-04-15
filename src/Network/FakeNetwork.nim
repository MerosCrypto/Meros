#Provide Network objects/fake Network procs so main compiles.

import asyncdispatch

import ../lib/Errors

import ../objects/ConfigObj
import ../objects/GlobalFunctionBoxObj

import ../Database/Merit/objects/BlockObj

import objects/MessageObj
import objects/NetworkObj
export MessageObj
export NetworkObj

proc broadcast*(
    network: Network,
    msg: Message
) {.async.} =
    discard

proc reply*(
    network: Network,
    msg: Message,
    res: Message
) {.async.} =
    discard

proc newNetwork*(
    id: int,
    protocol: int,
    mainFunctions: GlobalFunctionBox
): Network {.raises: [
    SocketError
].} =
    newNetworkObj(
        id,
        protocol,
        nil,
        nil,
        nil,
        mainFunctions
    )

proc listen*(
    network: Network,
    config: Config
) {.async.} =
    discard

proc connect*(
    network: Network,
    ip: string,
    port: int
) {.async.} =
    discard

proc shutdown*(
    network: Network
) {.raises: [
    SocketError
].} =
    discard

proc sync*(
    network: Network,
    newBlock: Block
): Future[bool] {.async.} =
    discard

proc requestBlock*(
    network: Network,
    nonce: int
): Future[bool] {.async.} =
    discard
