include MainImports

#Constants and Chain Params Type Definition.
#Some constants are defined in Nimscript and loaded via intdefine/strdefine.
#This is because they're for libraries which can't have their constants defined in a foreign file.

const
    #DB constants.
    MAX_DB_SIZE: int64 = 107374182400 #Max DB size.
    DB_VERSION: int = 0               #DB Version.

type ChainParams = object
    #Genesis.
    GENESIS: string

    #Target Block Time in seconds.
    BLOCK_TIME: int
    #Blocks before Merit dies.
    LIVE_MERIT: int

    #Initial Blockchain Difficulty.
    BLOCK_DIFFICULTY: string
    #Initial Send Difficulty.
    SEND_DIFFICULTY: string
    #Initial Data Difficulty.
    DATA_DIFFICULTY: string

    #Network ID.
    NETWORK_ID: int
    #Protocol version.
    NETWORK_PROTOCOL: int
