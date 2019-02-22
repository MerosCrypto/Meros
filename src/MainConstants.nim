include MainImports

#Constants. This acts as a sort-of "chain params".
#Some constants are defined in Nimscript and loaded via intdefine/strdefine.
#This is because they're for libraries which can't have their constants defined in a foreign file.
const
    #Merit constants.
    GENESIS: string =          #Genesis string.
        "MEROS_DEVELOPER_TESTNET_2"
    BLOCK_DIFFICULTY: string = #Blockchain difficulty at the start.
        "FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    BLOCK_TIME: uint = 600     #Block time in seconds.
    LIVE_MERIT: uint = 1000    #Blocks before Merit dies.

    #Lattice constants.
    TRANSACTION_DIFFICULTY: string = #Transaction difficulty at the start.
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    DATA_DIFFICULTY: string =        #Data difficulty at the start.
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"

    #Network constants.
    NETWORK_ID: uint = 0       #Network ID.
    NETWORK_PROTOCOL: uint = 0 #Protocol version.
