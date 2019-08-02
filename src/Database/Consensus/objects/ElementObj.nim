#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

#Element object.
finalsd:
    type
        Element* = ref object of RootObj
            #Public key of owner
            holder* {.final.}: BLSPublicKey
            #Nonce
            nonce* {.final.}: int
