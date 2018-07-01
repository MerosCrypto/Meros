import SECP256K1
export secp256k1_pubkey

import strutils

var context: ptr secp256k1_context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN or SECP256K1_CONTEXT_VERIFY)

proc secpPublicKey*(privKey: ptr array[32, uint8]): secp256k1_pubkey =
    result = secp256k1_pubkey()

    discard secp256k1_ec_pubkey_create(
        context,
        addr result,
        cast[ptr cuchar](privKey)
    )

proc secpPublicKey*(pubKey: string): secp256k1_pubkey =
    result = secp256k1_pubkey()

    for i in countup(0, 127, 2):
        result.data[(int) i / 2] = (uint8) parseHexInt(pubKey[i .. i + 1])

proc secpSignature*(sig: string): secp256k1_ecdsa_signature =
    result = secp256k1_ecdsa_signature()

    for i in countup(0, 127, 2):
        result.data[(int) i / 2] = (uint8) parseHexInt(sig[i .. i + 1])

proc `$`*(sig: secp256k1_ecdsa_signature): string =
    result = ""
    for i in 0 ..< 64:
        result = result & sig.data[i].toHex()

proc secpSign*(hash: var string, privKey: ptr array[32, uint8]): string =
    var sig: secp256k1_ecdsa_signature = secp256k1_ecdsa_signature()

    discard secp256k1_ecdsa_sign(
        context,
        addr sig,
        cast[ptr cuchar]((cstring) hash),
        cast[ptr cuchar](privKey),
        nil,
        nil
    )

    result = $sig

proc secpVerify*(hash: var string, pubKey: var secp256k1_pubkey, sigArg: string): bool =
    var sig: secp256k1_ecdsa_signature = secpSignature(sigArg)
    result = secp256k1_ecdsa_verify(
        context,
        addr sig,
        cast[ptr cuchar]((cstring) hash),
        addr pubKey
    ) == 1
