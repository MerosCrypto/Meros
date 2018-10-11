#Errors lib.
import ../lib/Errors

#RPC.
import RPC/RPC
export RPC

#GUI.
when not defined(nogui):
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
        fromMain {.final.}: Channel[string]
        toRPC {.final.}: Channel[JSONNode]
        toGUI {.final.}: Channel[JSONNode]
        rpc {.final.}: RPC

#Constructor.
proc newUI*(
    events: EventEmitter,
    width: int,
    height: int,
    port: uint
): UI {.raises: [AsyncError, ChannelError, SocketError, WebViewError].} =
    #Create the UI object.
    result = UI()

    #Open the channels.
    result.fromMain.open()
    result.toRPC.open()
    result.toGUI.open()

    #Create the RPC.
    result.rpc = newRPC(events, addr result.toRPC, addr result.toGUI)
    try:
        #Start the RPC.
        asyncCheck result.rpc.start()
        #Start listening.
        asyncCheck result.rpc.listen(port)
    except:
        raise newException(AsyncError, "Couldn't start the RPC.")

    when not defined(nogui):
        #Spawn the GUI.
        spawn newGUI(addr result.fromMain, addr result.toRPC, addr result.toGUI, width, height)

#Shutdown.
proc shutdown*(ui: UI) {.raises: [ChannelError].} =
    #Shutdown the GUI.
    try:
        ui.fromMain.send("shutdown")
    except:
        raise newException(ChannelError, "Couldn't send shutdown to the GUI.")
    
    #Shutdown the RPC.
    ui.rpc.shutdown()
