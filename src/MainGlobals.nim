include MainConstants

#Global variables used throughout Main.
var
    #Global Function Box.
    functions: GlobalFunctionBox = newGlobalFunctionBox()

    #Config.
    config: Config = newConfig()

    #Consensus.
    consensus {.threadvar.}: Consensus

    #Merit.
    merit {.threadvar.}: Merit

    #Transactions.
    transactions {.threadvar.}: Transactions

    #DB.
    database {.threadvar.}: DB

    #Personal.
    verifyLock: Lock               #Verify lock to stop us from triggering a MeritRemoval.
    wallet {.threadvar.}: HDWallet #Wallet.

    #Network.
    #network {.threadvar.}: Network #Network.

    #UI.
    fromMain: Channel[string] #Channel from the 'main' thread to the UI thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

#Function to safely shut down all elements of the node.
functions.system.quit = proc () {.forceCheck: [].} =
    #Shutdown the GUI.
    try:
        fromMain.send("shutdown")
    except DeadThreadError as e:
        echo "Couldn't shutdown the GUI due to a DeadThreadError: " & e.msg
    except Exception as e:
        echo "Couldn't shutdown the GUI due to an Exception: " & e.msg

    #Shutdown the RPC.
    rpc.shutdown()

    #Shut down the Network.
    #network.shutdown()

    #Shut down the DB.
    try:
        database.close()
    except DBError as e:
        echo "Couldn't shutdown the DB: " & e.msg

    #Quit.
    quit(0)
