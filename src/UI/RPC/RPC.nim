#RPC object.
import objects/RPCObj
export RPCObj

#RPC modules.
import Modules/SystemModule
import Modules/WalletModule
import Modules/BlockchainModule
import Modules/LatticeModule
import Modules/NetworkModule

#EventEmitter lib.
import ec_events

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Constructor.
proc newRPC*(
    events: EventEmitter,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.raises: [].} =
    result = newRPCObject(
        events,
        toRPC,
        toGUI
    )

#Start up the RPC.
proc start*(rpc: RPC) {.async.} =
    #Define the data outside of the loop.
    var data: tuple[dataAvailable: bool, msg: JSONNode]

    while rpc.listening:
        #Allow other async code to execute.
        await sleepAsync(1)

        #Try to get a message from the channel.
        data = rpc.toRPC[].tryRecv()
        #If there's no data, continue.
        if not data.dataAvailable:
            continue

        #Handle the data.
        try:
            case data.msg["module"].getStr():
                of "system":
                    rpc.systemModule(data.msg)
                of "wallet":
                    rpc.walletModule(data.msg)
                of "blockchain":
                    rpc.blockchainModule(data.msg)
                of "lattice":
                    rpc.latticeModule(data.msg)
                of "network":
                    rpc.networkModule(data.msg)
        except:
            echo getCurrentExceptionMsg()

#Shutdown.
proc shutdown*(rpc: RPC) {.raises: [].} =
    rpc.listening = false
