import SECP256K1/secp256k1

var context: ptr secp256k1_context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN or SECP256K1_CONTEXT_VERIFY)

var
    privateKey: array[32, uint8]
    publicKey: secp256k1_pubkey

discard secp256k1_ec_pubkey_create(context, addr publicKey,
    cast[ptr cuchar] (addr privateKey[0])
)
