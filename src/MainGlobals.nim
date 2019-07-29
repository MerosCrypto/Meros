include MainChainParams

#Global variables used throughout Main.
var
    #Global Function Box.
    functions: GlobalFunctionBox = newGlobalFunctionBox()

    #Config.
    config: Config = newConfig()

    #Chain Parames.
    params: ChainParams

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
    wallet {.threadvar.}: Wallet   #Wallet.

    #Network.
    network {.threadvar.}: Network #Network.

    #Interfaces.
    fromMain: Channel[string] #Channel from the 'main' thread to the Interfaces thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

case config.network:
    of "mainnet":
        doAssert(false, "The mainnet has yet to launch.")

    of "testnet":
        params = ChainParams(
            GENESIS: "MEROS_DEVELOPER_TESTNET_2",

            BLOCK_TIME: 600,
            LIVE_MERIT: 1000,

            BLOCK_DIFFICULTY: "FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            SEND_DIFFICULTY:  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            DATA_DIFFICULTY:  "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",

            NETWORK_ID: 1,
            NETWORK_PROTOCOL: 0
        )

    of "devnet":
        params = ChainParams(
            GENESIS: "MEROS_DEVELOPER_NETWORK",

            BLOCK_TIME: 60,
            LIVE_MERIT: 100,

            BLOCK_DIFFICULTY: "FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            SEND_DIFFICULTY:  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            DATA_DIFFICULTY:  "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",

            #By not using 255, we allow eventually extending these fields. If we read 255, we also read an extra byte,
            NETWORK_ID: 254,
            NETWORK_PROTOCOL: 254
        )

    else:
        doAssert(false, "Invalid network specified.")

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
    network.shutdown()

    #Shut down the DB.
    try:
        database.close()
    except DBError as e:
        echo "Couldn't shutdown the DB: " & e.msg

    #Quit.
    quit(0)
