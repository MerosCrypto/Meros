import ../../Wallet/MinerWallet

import finals

finalsd:
    type
        Element* = ref object of RootObj
            #Public key of owner
            holder* {.final.}: BLSPublicKey
            #Nonce
            nonce* {.final.}: Natural


