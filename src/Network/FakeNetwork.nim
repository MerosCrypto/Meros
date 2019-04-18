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
) {.forceCheck: [], async.} =
    discard

proc newNetwork*(
    id: int,
    protocol: int,
    mainFunctions: GlobalFunctionBox
): Network {.raises: [].} =
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
) {.forceCheck: [], async.} =
    discard

proc connect*(
    network: Network,
    ip: string,
    port: int
) {.forceCheck: [], async.} =
    discard

proc shutdown*(
    network: Network
) {.raises: [].} =
    discard

proc requestBlock*(
    network: Network,
    nonce: int
) {.forceCheck: [], async.} =
    discard
