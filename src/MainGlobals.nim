include MainChainParams

#Global variables used throughout Main.
var
    #Global Function Box.
    functions {.threadvar.}: GlobalFunctionBox

    #Config.
    config: Config = newConfig()

    #Chain Parames.
    params {.threadvar.}: ChainParams

    #Consensus.
    consensus {.threadvar.}: Consensus

    #Merit.
    merit {.threadvar.}: Merit
    blockLock {.threadvar.}: ref Lock
    innerBlockLock {.threadvar.}: ref Lock
    lockedBlock {.threadvar.}: Hash[256]

    #Transactions.
    transactions {.threadvar.}: Transactions

    #DB.
    database {.threadvar.}: DB

    #WalletDB.
    wallet {.threadvar.}: WalletDB

    #Network.
    network {.threadvar.}: Network

    #Interfaces.
    fromMain: Channel[string] #Channel from the 'main' thread to the Interfaces thread.
    toRPC: Channel[JSONNode]  #Channel to the RPC from the GUI.
    toGUI: Channel[JSONNode]  #Channel to the GUI from the RPC.
    rpc {.threadvar.}: RPC    #RPC object.

case config.network:
    of "mainnet":
        echo "The mainnet has yet to launch."
        quit(0)

    of "testnet":
        params = ChainParams(
            GENESIS: "MEROS_DEVELOPER_TESTNET_2",

            BLOCK_TIME: 600,
            DEAD_MERIT: 1000,

            BLOCK_DIFFICULTY: 10000,
            SEND_DIFFICULTY:  3,
            DATA_DIFFICULTY:  5,

            NETWORK_PROTOCOL: 0,
            NETWORK_ID: 0,

            SEEDS: @[
                (ip: "seed1.meroscrypto.io", port: 5132),
                (ip: "seed2.meroscrypto.io", port: 5132),
                (ip: "seed3.meroscrypto.io", port: 5132),
            ]
        )

    of "devnet":
        params = ChainParams(
            GENESIS: "MEROS_DEVELOPER_NETWORK",

            BLOCK_TIME: 60,
            DEAD_MERIT: 100,

            BLOCK_DIFFICULTY: 100,
            SEND_DIFFICULTY:  3,
            DATA_DIFFICULTY:  5,

            #By not using 255, we allow eventually extending these fields. If we read 255, we can also read an extra byte,
            NETWORK_PROTOCOL: 254,
            NETWORK_ID: 254,

            SEEDS: @[]
        )

    else:
        echo "Invalid network specified."
        quit(0)

#Start the logger.
if not (addr defaultChroniclesStream.output).open(config.dataDir / config.logFile, fmAppend):
    echo "Couldn't open the log file."
    quit(0)
