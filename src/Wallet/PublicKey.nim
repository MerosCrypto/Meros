import ../lib/SHA512
import ../lib/SECP256K1Wrapper

import PrivateKey

import strutils

type PublicKey* = ptr secp256k1_pubkey

proc newPublicKey*(privKey: PrivateKey): PublicKey =
    result = secpPublicKey(privKey.secret)

proc newPublicKey*(hex: string): PublicKey =
    result = secpPublicKey(hex)

proc `$`*(key: PublicKey): string =
    result = ""
    for i in 0 ..< 64:
        echo i
        result = result & key.data[i].toHex()

proc verify*(key: PublicKey, msg: string, sig: string): bool =
    var hash: string = SHA512(msg)
    secpVerify(hash, key, sig)
