include MainImports

#Constants and Chain Params Type Definition.
#Some constants are defined in Nimscript and loaded via intdefine/strdefine.
#This is because they're for libraries which can't have their constants defined in a foreign file.

const
  #DB constants.
  MAX_DB_SIZE: int64 = 107374182400 #Max DB size.
  DB_VERSION: int = 0               #DB Version.

type ChainParams = object
  GENESIS: string

  #Target Block Time in seconds.
  BLOCK_TIME: int
  #Blocks before Merit dies.
  DEAD_MERIT: int

  #Initial Blockchain Difficulty.
  BLOCK_DIFFICULTY: uint64
  #Initial Send Difficulty.
  SEND_DIFFICULTY: uint32
  #Initial Data Difficulty.
  DATA_DIFFICULTY: uint32

  NETWORK_PROTOCOL: int
  NETWORK_ID: int

  SEEDS: seq[tuple[ip: string, port: int]]

proc newChainParams(
  network: string
): ChainParams {.forceCheck: [].} =
  case network:
    of "mainnet":
      echo "The mainnet has yet to launch."
      quit(0)

    of "testnet":
      result = ChainParams(
        GENESIS: "MEROS_DEVELOPER_TESTNET_5.1",

        #The following is a temporary value for before the mainnet launches.
        BLOCK_TIME: 120,
        DEAD_MERIT: 1000,

        BLOCK_DIFFICULTY: 1000,
        SEND_DIFFICULTY:  3,
        DATA_DIFFICULTY:  5,

        NETWORK_PROTOCOL: 0,
        NETWORK_ID: 1,

        SEEDS: @[
          (ip: "seed1.meroscrypto.io", port: 5132),
          (ip: "seed2.meroscrypto.io", port: 5132),
          (ip: "seed3.meroscrypto.io", port: 5132),
        ]
      )

    of "devnet":
      result = ChainParams(
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

#Create the Function Box globally so the CTRL-C hook has access.
var functionsGlobal: GlobalFunctionBox = newGlobalFunctionBox()
