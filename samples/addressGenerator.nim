import Wallet/PrivateKey
import Wallet/PublicKey
import Wallet/Address

for i in 0 .. 500:
    var privKey: PrivateKey = newPrivateKey()
    var pubKey: PublicKey = newPublicKey(privKey)
    var address: string = newAddress($pubKey)

    if Address.verify(address) == false:
        raise newException(Exception, "Invalid Address Type 1")
    if Address.verify(address, $pubKey) == false:
        raise newException(Exception, "Invalid Address Type 2")

    echo address
