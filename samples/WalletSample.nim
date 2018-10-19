#Base lib.
import ../src/lib/Base

#Hash lib.
import ../src/lib/Hash

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
