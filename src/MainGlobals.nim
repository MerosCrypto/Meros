include MainConstants

#Global variables used throughout Main.
var
    events: EventEmitter = newEventEmitter() #EventEmitter for queries and new data.

    #Merit.
    merit {.threadvar.}: Merit #Blockchain and state.
    miner {.threadvar.}: bool  #Miner boolean.

    #Lattice.
    lattice {.threadvar.}: Lattice   #Lattice.
    genesisSend {.threadvar.}: Index #Genesis Send. Puts the first coins on the network.

    #Network.
    network {.threadvar.}: Network #Network.

    #UI.
    fromMain: Channel[string] #Channel from the 'main' thread to the UI thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

#If the miner argument was passed...
if paramStr(1) == "--miner":
    miner = true

#Properly shutdown.
events.on(
    "system.quit",
    proc () {.raises: [ChannelError, SocketError].} =
        #Shutdown the GUI.
        try:
            fromMain.send("shutdown")
        except:
            raise newException(ChannelError, "Couldn't send shutdown to the GUI.")

        #Shutdown the RPC.
        rpc.shutdown()

        #Shut down the Network.
        network.shutdown()

        #Quit.
        quit(0)
)
