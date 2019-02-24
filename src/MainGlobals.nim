include MainConstants

#Global variables used throughout Main.
var
    #Global Function Box.
    functions: GlobalFunctionBox = newGlobalFunctionBox()

    #Config.
    config: Config = newConfig()

    #Verifications.
    verifications {.threadvar.}: Verifications

    #Merit.
    merit {.threadvar.}: Merit

    #Lattice.
    lattice {.threadvar.}: Lattice

    #DB.
    db {.threadvar.}: DB

    #Personal.
    verifyLock: Lock             #Verify lock to stop us from trigerring a MeritRemoval.
    wallet {.threadvar.}: Wallet #Wallet.

    #Network.
    network {.threadvar.}: Network #Network.

    #UI.
    fromMain: Channel[string] #Channel from the 'main' thread to the UI thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

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

    #Shut down the DB.
    db.close()

    #Quit.
    quit(0)
