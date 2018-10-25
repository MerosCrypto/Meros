include MainImports

#Constants. This acts as a sort-of "chain params".
#Some constants are defined in Nimscript and loaded via intdefine/strdefine.
#This is because they're for libraries which can't have their constants defined in a foreign file.
const
    #Merit constants.
    GENESIS: string =          #Genesis string.
        "EMB_DEVELOPER_TESTNET"
    BLOCK_DIFFICULTY: string = #Blockchain difficulty at the start.
        "D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0"
    BLOCK_TIME: uint = 600     #Block time in seconds.
    LIVE_MERIT: uint = 1000    #Blocks before Merit dies.

    #Lattice constants.
    TRANSACTION_DIFFICULTY: string = #Transaction difficulty at the start.
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    DATA_DIFFICULTY: string =        #Data difficulty at the start.
        "E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0"
    MINT_ADDRESS: string =           #Address to send the Genesis Coins to.
        "Emb6v2efdjg79w20z9z29sp52af76najafjtrtl7z5jf7e0zmlwd20qf4jcl9"
    MINT_SEED: string =              #Seed of the address the Genesis Coins were sent to.
        "F0594F2052E00039236FD163971C150BBAC1687AF42580AEADC3D75BC3B4427F"
    MINT_AMOUNT: string =            #Amount of coins for the Genesis Send.
        "1000000"

    #Network constants.
    NETWORK_ID: uint = 0       #Network ID.
    NETWORK_PROTOCOL: uint = 0 #Protocol version.
    NETWORK_PORT: uint = 5132  #Port to listen on.

    #UI constants.
    RPC_PORT: uint = 5133
