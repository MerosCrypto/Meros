import ../lib/SHA512 as SHA512File
import ../lib/SECP256K1Wrapper

import PrivateKey

import strutils

type PublicKey* = secp256k1_pubkey

proc newPublicKey*(privKey: PrivateKey): PublicKey {.raises: [ValueError].} =
    result = secpPublicKey(privKey)

proc newPublicKey*(hex: string): PublicKey {.raises: [ValueError].} =
    result = secpPublicKey(hex)

proc `$`*(key: PublicKey): string {.raises: [ValueError].} =
    result = $!(key)

proc verify*(key: PublicKey, msg: string, sig: string): bool {.raises: [ValueError, Exception].} =
    key.secpVerify((SHA512^2)(msg), sig)
