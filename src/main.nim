#Number libs.
import lib/BN
import lib/Base

#SHA512 lib.
import lib/SHA512 as SHA512File

#Block, blockchain, and State libs.
import DB/Merit/Merit

#Wallet libs.
import Wallet/Wallet

import DB/Lattice/Transaction

#Demo.
var
    wallet: Wallet = newWallet()
    hash: string = SHA512("test")
    sig: string = wallet.sign(hash)
    res: bool = wallet.getPublicKey().verify(hash, sig)

echo res
