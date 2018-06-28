import SECP256K1/secp256k1
export secp256k1_pubkey

import strutils

var context: ptr secp256k1_context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN or SECP256K1_CONTEXT_VERIFY)

proc secpPublicKey*(privKey: ptr array[32, uint8]): ptr secp256k1_pubkey =
    result = cast[ptr secp256k1_pubkey](alloc0(sizeof(secp256k1_pubkey)))

    discard secp256k1_ec_pubkey_create(
        context,
        result,
        cast[ptr cuchar](privKey)
    )

proc secpPublicKey*(pubKey: string): ptr secp256k1_pubkey =
    result = cast[ptr secp256k1_pubkey](alloc0(sizeof(secp256k1_pubkey)))

    for i in countup(0, 127, 2):
        result.data[(int) i / 2] = (uint8) parseHexInt(pubKey[i .. i + 1])

proc secpSignature*(sig: string): ptr secp256k1_ecdsa_signature =
    result = cast[ptr secp256k1_ecdsa_signature](alloc0(sizeof(secp256k1_ecdsa_signature)))

    for i in countup(0, 127, 2):
        result.data[(int) i / 2] = (uint8) parseHexInt(sig[i .. i + 1])

proc `$`*(sig: secp256k1_ecdsa_signature): string =
    result = ""
    for i in 0 ..< 64:
        result = result & sig.data[i].toHex()

proc secpSign*(hash: var string, privKey: ptr array[32, uint8]): string =
    var sig: ptr secp256k1_ecdsa_signature = cast[ptr secp256k1_ecdsa_signature](alloc0(sizeof(secp256k1_ecdsa_signature)))

    discard secp256k1_ecdsa_sign(
        context,
        sig,
        cast[ptr cuchar](addr hash[0]),
        cast[ptr cuchar](privKey),
        nil,
        nil
    )

    result = $(sig[])

proc secpVerify*(hash: var string, pubKey: ptr secp256k1_pubkey, sig: string): bool =
    result = secp256k1_ecdsa_verify(
        context,
        secpSignature(sig),
        cast[ptr cuchar](addr hash[0]),
        pubKey
    ) == 1
