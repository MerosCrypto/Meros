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
    BLOCK_TIME: int = 600        #Block time in seconds.
    LIVE_MERIT: int = 50000      #Blocks before Merit dies.

    #Lattice constants.
    TRANSACTION_DIFFICULTY: string = #Transaction difficulty at the start.
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    DATA_DIFFICULTY: string =        #Data difficulty at the start.
        "E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0E0"
    MINT_ADDRESS: string =           #Address to send the Genesis Coins to.
        "Emb0h3nyv8uplrx68677ca6t0t4x6qhsue90y50ntwq3dfj5hxw246s"
    MINT_KEY: string =               #Private Key of the address Genesis Coins were sent to.
        "7A3E64ADDB86DA2F3D1BEF18F6D2C80BA5C5EF9673DE8A0F5787DF8E6DD23742" &
        "7DE33230FC0FC66D1F5EF63BA5BD7536817873257928F9ADC08B532A5CCE5575"
    MINT_AMOUNT: string =            #Amount of coins for the Genesis Send.
        "1000000"

    #Network constants.
    NETWORK_ID: int = 0       #Network ID.
    NETWORK_PROTOCOL: int = 0 #Protocol version.
    NETWORK_PORT: int = 5132  #Port to listen on.
