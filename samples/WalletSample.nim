#Number libs.
import BN
import ../src/lib/Base

#Hash lib.
import ../src/lib/Hash

#Block, blockchain, and State libs.
import ../src/Database/Merit/Merit

#Wallet libs.
import ../src/Wallet/Wallet

#Demo.
var
    wallet: Wallet = newWallet()
    hash: string = SHA512("test")
    sig: string = wallet.sign(hash)
    res: bool = wallet.getPublicKey().verify(hash, sig)

echo res
