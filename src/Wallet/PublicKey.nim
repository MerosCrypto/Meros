import ../lib/SHA512
import ../lib/SECP256K1Wrapper

import PrivateKey

import strutils

type PublicKey* = ref object of RootObj
    initiated: bool
    key: secp256k1_pubkey

proc newPublicKey*(privKey: PrivateKey): PublicKey =
    result = PublicKey(
        initiated: true,
        key: secpPublicKey(addr privKey.secret)
    )

proc newPublicKey*(hex: string): PublicKey =
    result = PublicKey(
        initiated: true,
        key: secpPublicKey(hex)
    )

proc `$`*(key: PublicKey): string =
    if key.initiated != true:
        result = "0"
        return

    result = ""
    for i in 0 ..< 64:
        result = result & key.key.data[i].toHex()

proc verify*(key: PublicKey, msg: string, sig: string): bool =
    var hash: string = SHA512(msg)
    secpVerify(hash, key.key, sig)
