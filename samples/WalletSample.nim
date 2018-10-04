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
    hash: string = SHA512("test").toString()
    sig: string = wallet.sign(hash)
    pubKey: PublicKey = newPublicKey(wallet.address.toBN().toString(256))
    res: bool = pubKey.verify(hash, sig)

echo res
