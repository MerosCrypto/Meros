#RPC object.
import objects/RPCObj
export RPCObj

#EventEmitter lib.
import ec_events

#Async standard lib.
import asyncdispatch

#Constructor.
proc newRPC*(
    events: EventEmitter,
    toRPC: ptr Channel[string],
    toGUI: ptr Channel[string]
): RPC =
    result = newRPCObject(
        events,
        toRPC,
        toGUI
    )

#Start up the RPC.
proc start*(rpc: RPC) {.async.} =
    #Define the data outside of the loop.
    var data: tuple[dataAvailable: bool, msg: string]

    while rpc.listening:
        #Allow other async code to execute.
        await sleepAsync(1)

        #Try to get a message from the channel.
        data = rpc.toRPC[].tryRecv()
        #If there's no data, continue.
        if not data.dataAvailable:
            continue

        #Handle the data.
        echo data.msg

        #Send back an empty response for now.
        rpc.toGUI[].send("")

#Shutdown.
proc shutdown*(rpc: RPC) {.raises: [].} =
    rpc.listening = false
