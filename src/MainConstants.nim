include MainImports

#Constants. This acts as a sort-of "chain params".
#Some constants are defined in Nimscript and loaded via strdefine.
#This is because they're for libraries which can't have their constants defined in a foreign file.
const
    #Merit constants.
    GENESIS: string =            #Genesis string.
        "EMB_MAINNET"
    BLOCK_DIFFICULTY: string =   #Blockchain difficulty at the start.
        "D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0D0"
    BLOCK_TIME: uint = 600        #Block time in seconds.
    LIVE_MERIT: uint = 50000      #Blocks before Merit dies.

    #Lattice constants.
    TRANSACTION_DIFFICULTY: string = #Transaction difficulty at the start.
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    DATA_DIFFICULTY: string =        #Data difficulty at the start.
        "E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0"
    MINT_ADDRESS: string =           #Address to send the Genesis Coins to.
        "Embklvfywjhglknpv7gj6seu8nxrdmcd5ave9awyzu3yd59tjr6ldzsn5l0tn"
    MINT_KEY: string =               #Private Key of the address Genesis Coins were sent to.
        "9A39A71D891557EC2C10F164D322D6A60460D59F39800BCCFB10A6D8C3F1B541" &
        "B7D8923A5747ED30B3C896A19E1E661B7786D3ACC97AE20B91236855C87AFB45"
    MINT_AMOUNT: string =            #Amount of coins for the Genesis Send.
        "1000000"
    
    #Network constants.
    NETWORK_ID: int = 0       #Network ID.
    NETWORK_PROTOCOL: int = 0 #Protocol version.
    NETWORK_PORT: int = 5132  #Port to listen on.

    #UI constants.
    RPC_PORT: int = 5133
