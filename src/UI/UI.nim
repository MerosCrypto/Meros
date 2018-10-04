#Errors lib.
import ../lib/Errors

#RPC.
import RPC/RPC
export RPC
#GUI.
import GUI/GUI
export GUI

#EventEmitter lib.
import ec_events

#Finals lib.
import finals

#Async standard lib.
import asyncdispatch

#Thread standard lib.
import threadpool

#JSON standard lib.
import json

#UI object.
finalsd:
    type UI* = ref object of RootObj
        toGUI {.final.}: Channel[JSONNode]
        toRPC {.final.}: Channel[JSONNode]
        rpc {.final.}: RPC

#Constructor.
proc newUI*(
    events: EventEmitter,
    width: int,
    height: int
): UI {.raises: [AsyncError, WebViewError].} =
    #Create the UI object.
    result = UI()

    #Open the channels.
    result.toRPC.open()
    result.toGUI.open()

    #Create the RPC.
    result.rpc = newRPC(events, addr result.toRPC, addr result.toGUI)
    try:
        #Start the RPC.
        asyncCheck result.rpc.start()
    except:
        raise newException(AsyncError, "Couldn't start the RPC.")

    #Spawn the GUI.
    spawn newGUI(addr result.toRPC, addr result.toGUI, width, height)

#Shutdown.
proc shutdown*(ui: UI) {.raises: [].} =
    #Shutdown the RPC.
    ui.rpc.shutdown()
