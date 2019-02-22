include MainConstants

#Global variables used throughout Main.
var
    #Global Function Box.
    functions: GlobalFunctionBox = newGlobalFunctionBox()

    #Config.
    config: Config = newConfig()

    #Verifications.
    verifications: Verifications

    #Merit.
    merit: Merit #Blockchain and state.

    #Lattice.
    lattice: Lattice #Lattice.

    #Personal.
    verifyLock: Lock #Verify Lock.
    wallet: Wallet   #Wallet.

    #Network.
    network: Network #Network.

    #UI.
    fromMain: Channel[string] #Channel from the 'main' thread to the UI thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc: RPC    #RPC object.

#Properly shutdown.
functions.system.quit = proc () {.raises: [ChannelError, AsyncError, SocketError].} =
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
