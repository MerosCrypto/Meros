import PrivateKey as PrivateKeyFile
import PublicKey as PublicKeyFile
import Address
export PrivateKeyFile, PublicKeyFile, Address

import finals

finalsd:
    type Wallet* = ref object of RootObj
        privateKey* {.final.}: PrivateKey
        publicKey* {.final.}: PublicKey
        address* {.final.}: string

proc newWallet*(
    privateKey: PrivateKey = newPrivateKey()
): Wallet {.raises: [Exception].} =
    result = Wallet(
        privateKey: privateKey,
        publicKey:  newPublicKey(privateKey)
    )
    result.address = newAddress(result.publicKey)

proc newWallet*(privateKey: string): Wallet {.raises: [ValueError, Exception].} =
    newWallet(newPrivateKey(privateKey))

proc newWallet*(
    privateKey: PrivateKey,
    publicKey: PublicKey
): Wallet {.raises: [ValueError, Exception].} =
    result = newWallet(privateKey)
    if $result.publicKey != $publicKey:
        raise newException(ValueError, "Invalid Public Key for this Private Key.")

proc newWallet*(
    privateKey: PrivateKey,
    publicKey: PublicKey,
    address: string
): Wallet {.raises: [ValueError, Exception].} =
    result = newWallet(privateKey, publicKey)
    if result.address != address:
        raise newException(ValueError, "Invalid Address for this Public Key.")

proc sign*(wallet: Wallet, msg: string): string {.raises: [Exception].} =
    result = wallet.privateKey.sign(msg)

proc verify*(wallet: Wallet, msg: string, sig: string): bool {.raises: [Exception].} =
    result = wallet.publicKey.verify(msg, sig)
