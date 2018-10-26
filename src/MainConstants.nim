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
    MINT_PUBKEY: string =            #BLS Public Key to send the Genesis Coins to.
        "8D3C55ADD204563601887A381DDA81D93A57DA899D366AE8001626DE56640451025EB796F484AE15439246FFB7E53FFC"
    MINT_PRIVKEY: string =           #BLS Private Key to send the Genesis Coins to.
        "3ABE2A722A3B36E3331792EAF2432ED8F95685A740E6EF4D05E5008AB95F5BA4"
    MINT_AMOUNT: string =            #Amount of coins for the Genesis Send.
        "1000000"

    #Network constants.
    NETWORK_ID: uint = 0       #Network ID.
    NETWORK_PROTOCOL: uint = 0 #Protocol version.
    NETWORK_PORT: uint = 5132  #Port to listen on.

    #UI constants.
    RPC_PORT: uint = 5133
