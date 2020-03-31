#[
The Main files are an "include chain". They include each other sequentially, in the following orders:
    MainImports
    MainChainParams
    MainDatabase
    MainReorganization
    MainMerit
    MainConsensus
    MainTransactions
    MainPersonal
    MainNetwork
    MainInterfaces

We could include all of them in this file, but then all the other files would throw errors.
IDEs can't, and shouldn't, detect that an external file includes that file, and the external file resolves the dependency requirements.
]#

#Include the last file in the chain.
include MainInterfaces

#Config.
var globalConfig {.threadvar.}: Config
globalConfig = newConfig()

#Start the logger.
if not (addr defaultChroniclesStream.output).open(globalConfig.dataDir / globalConfig.logFile, fmAppend):
    echo "Couldn't open the log file."
    quit(0)

#Enable running main on a thread since the GUI must always run on the main thread.
proc main(
    config: Config
) {.thread.} =
    var
        #DB.
        database {.threadvar.}: DB
        #WalletDB.
        wallet {.threadvar.}: WalletDB

        #Function Box.
        functions {.threadvar.}: GlobalFunctionBox

        #Chain Parames.
        params {.threadvar.}: ChainParams

        #Consensus.
        consensus {.threadvar.}: ref Consensus

        #Merit.
        #Merit is already a ref object. That said, we need to assign to it, and `var ref`s are illegal.
        merit {.threadvar.}: ref Merit
        blockLock {.threadvar.}: ref Lock
        innerBlockLock {.threadvar.}: ref Lock
        lockedBlock {.threadvar.}: ref Hash[256]

        #Transactions.
        transactions {.threadvar.}: ref Transactions

        #Network.
        network {.threadvar.}: Network

        #RPC.
        rpc {.threadvar.}: RPC

    functions = newGlobalFunctionBox()
    params = newChainParams(config.network)
    consensus = new(Consensus)
    merit = new(ref Merit)
    blockLock = new(Lock)
    innerBlockLock = new(Lock)
    lockedBlock = new(Hash[256])
    transactions = new(Transactions)

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

        #Shut down the databases.
        try:
            database.close()
            wallet.close()
        except DBError as e:
            echo "Couldn't shutdown the DB: " & e.msg

        #Quit.
        quit(0)

    initLock(blockLock[])
    initLock(innerBlockLock[])

    mainDatabase(config, database, wallet)
    mainMerit(params, database, wallet, functions, merit, consensus, transactions, network, blockLock, innerBlockLock, lockedBlock)
    mainConsensus(params, database, functions, merit, consensus, transactions, network)
    mainTransactions(database, wallet, functions, merit, consensus, transactions)
    mainPersonal(wallet, functions, transactions)
    mainNetwork(params, config, functions, network)
    mainRPC(config, functions, rpc)

    runForever()

#If we weren't compiled with a GUI...
when defined(nogui):
    #Run main.
    main(globalConfig)
#If we were...
else:
    #If it's disabled...
    if not globalConfig.gui:
        main(globalConfig)
    #If it's enabled...
    else:
        #Spawn main on a thread.
        spawn main(globalConfig)
        #Run the GUI on the main thread,
        mainGUI()
        #If WebView exits, perform a safe shutdown.
        toRPC.send(%* {
            "module": "system",
            "method": "quit",
            "args": []
        })
