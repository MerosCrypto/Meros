import PrivateKey
import PublicKey
import Address
export PrivateKey, PublicKey, Address

type Wallet* = ref object of RootObj
    priv: PrivateKey
    pub: PublicKey
    address: string

proc newWallet*(priv: PrivateKey = newPrivateKey()): Wallet =
    result = Wallet()
    result.priv = priv
    result.pub = newPublicKey(result.priv)
    result.address = newAddress(result.pub)

proc newWallet*(priv: PrivateKey, pub: PublicKey): Wallet {.raises: [ValueError, OverflowError, Exception].} =
    result = newWallet(priv)
    if $result.pub != $pub:
        raise newException(ValueError, "Invalid Public Key for this Private Key.")

proc newWallet*(priv: PrivateKey, pub: PublicKey, address: string): Wallet {.raises: [ValueError, OverflowError, Exception].} =
    result = newWallet(priv, pub)
    if result.address != address:
        raise newException(ValueError, "Invalid Address for this Public Key.")

proc `$`*(wallet: Wallet): string =
    result =
        $wallet.priv & "|" &
        $wallet.pub & "|" &
        wallet.address

proc sign*(wallet: Wallet, msg: string): string =
    result = wallet.priv.sign(msg)

proc verify*(wallet: Wallet, msg: string, sig: string): bool =
    result = wallet.pub.verify(msg, sig)

proc getPrivateKey*(wallet: Wallet): PrivateKey =
    result = wallet.priv

proc getPublicKey*(wallet: Wallet): PublicKey =
    result = wallet.pub

proc getAddress*(wallet: Wallet): string =
    result = wallet.address
