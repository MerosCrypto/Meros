#Number libs.
import lib/BN
import lib/Base

#SHA512 lib.
import lib/SHA512

#Block, blockchain, and State libs.
import Database/Merit/Merit

#Wallet libs.
import Wallet/Wallet

#Lattice file to make sure those files have valid syntax.
import Database/Lattice/Lattice

#Demo.
var
    wallet: Wallet = newWallet()
    hash: string = SHA512("test")
    sig: string = wallet.sign(hash)
    res: bool = wallet.getPublicKey().verify(hash, sig)

echo res
