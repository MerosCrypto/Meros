import SECP256K1/secp256k1
export secp256k1_pubkey

import strutils

var context: ptr secp256k1_context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN or SECP256K1_CONTEXT_VERIFY)

proc secpPublicKeyPtr(): ptr secp256k1_pubkey =
    result = cast[ptr secp256k1_pubkey](alloc0(sizeof(secp256k1_pubkey)))
    if result.isNil():
        raise newException(Exception, "Failed to allocate memory for a SECP256K1 Public Key.")


proc secpPublicKey*(privKey: ptr array[32, uint8]): ptr secp256k1_pubkey =
    result = secpPublicKeyPtr()

    discard secp256k1_ec_pubkey_create(
        context,
        result,
        cast[ptr cuchar](privKey)
    )

proc secpPublicKey*(pubKey: string): ptr secp256k1_pubkey =
    result = secpPublicKeyPtr()

    for i in countup(0, 127, 2):
        result.data[(int) i / 2] = (uint8) parseHexInt(pubKey[i .. i + 1])

proc secpSignaturePtr(): ptr secp256k1_ecdsa_signature =
    result = cast[ptr secp256k1_ecdsa_signature](alloc0(sizeof(secp256k1_ecdsa_signature)))
    if result.isNil():
        raise newException(Exception, "Failed to allocate memory for a SECP256K1 Signature.")

proc secpSignature*(sig: string): ptr secp256k1_ecdsa_signature =
    result = secpSignaturePtr()

    for i in countup(0, 127, 2):
        result.data[(int) i / 2] = (uint8) parseHexInt(sig[i .. i + 1])

proc `$`*(sig: secp256k1_ecdsa_signature): string =
    result = ""
    for i in 0 ..< 64:
        result = result & sig.data[i].toHex()

proc secpSign*(hash: var string, privKey: ptr array[32, uint8]): string =
    var sig: ptr secp256k1_ecdsa_signature = secpSignaturePtr()

    discard secp256k1_ecdsa_sign(
        context,
        sig,
        cast[ptr cuchar]((cstring) hash),
        cast[ptr cuchar](privKey),
        nil,
        nil
    )

    result = $(sig[])
    dealloc(sig)

proc secpVerify*(hash: var string, pubKey: ptr secp256k1_pubkey, sigArg: string): bool =
    var sig: ptr secp256k1_ecdsa_signature = secpSignature(sigArg)
    result = secp256k1_ecdsa_verify(
        context,
        sig,
        cast[ptr cuchar]((cstring) hash),
        pubKey
    ) == 1
    dealloc(sig)
