#Number libs.
import lib/BN
import lib/Base

#SHA512 lib.
import lib/SHA512

#Block, blockchain, and State libs.
import Database/Merit/Merit

#Wallet libs.
import Wallet/Wallet

#Demo.
var
    wallet: Wallet = newWallet()
    hash: string = SHA512("test")
    sig: string = wallet.sign(hash)
    res: bool = wallet.getPublicKey().verify(hash, sig)

echo res
