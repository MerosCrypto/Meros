include MainImports

#Constants. This acts as a sort-of "chain params".
#Some constants are defined in Nimscript and loaded via intdefine/strdefine.
#This is because they're for libraries which can't have their constants defined in a foreign file.
const
    #DB constants.
    MAX_DB_SIZE: int64 = 107374182400 #Max DB size.

    #Merit constants.
    GENESIS: string =          #Genesis string.
        "MEROS_DEVELOPER_TESTNET_2"
    BLOCK_DIFFICULTY: string = #Blockchain difficulty at the start.
        "FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    BLOCK_TIME: int = 600     #Block time in seconds.
    LIVE_MERIT: int = 1000    #Blocks before Merit dies.

    #Lattice constants.
    TRANSACTION_DIFFICULTY: string = #Transaction difficulty at the start.
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    DATA_DIFFICULTY: string =        #Data difficulty at the start.
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"

    #Network constants.
    NETWORK_ID: int = 0       #Network ID.
    NETWORK_PROTOCOL: int = 0 #Protocol version.
