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

#UI object.
finalsd:
    type UI* = ref object of RootObj
        toGUI {.final.}: Channel[string]
        toRPC {.final.}: Channel[string]
        rpc {.final.}: RPC

#Constructor.
proc newUI*(
    events: EventEmitter,
    width: int,
    height: int
): UI {.raises: [Exception].} =
    #Create the UI object.
    result = UI()

    #Open the channels.
    result.toRPC.open()
    result.toGUI.open()

    #Create the RPC.
    result.rpc = newRPC(events, addr result.toRPC, addr result.toGUI)
    #Start the RPC.
    asyncCheck result.rpc.start()

    #Spawn the GUI.
    spawn newGUI(addr result.toRPC, addr result.toGUI, width, height)

#Shutdown.
proc shutdown*(ui: UI) {.raises: [].} =
    #Shutdown the RPC.
    ui.rpc.shutdown()
