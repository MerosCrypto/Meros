#SECP256K1 libs.
import secp256k1
#Export the public key object for the PublicKey lib.
export secp256k1_pubkey

#Standard string utils lib.
import strutils

#SECP256K1 for signing and verifying messages.
var context: ptr secp256k1_context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN or SECP256K1_CONTEXT_VERIFY)

#Create a public key from a private key.
proc secpPublicKey*(privKeyArg: array[32, uint8]): secp256k1_pubkey {.raises: [ValueError].} =
    #Copy the object so we don't have to use var in the proc declaration.
    var privKey: array[32, uint8] = privKeyArg

    #Init the result.
    result = secp256k1_pubkey()
    #Create the public key.
    if secp256k1_ec_pubkey_create(
        context,
        addr result,
        cast[ptr cuchar](addr privKey)
    ) != 1:
        #If that failed...
        raise newException(ValueError, "Invalid Private Key.")

#Create a public key from a hex representation.
proc secpPublicKey*(pubKeyArg: string): secp256k1_pubkey {.raises: [ValueError].} =
    #Get the bytes from the hex string.
    var pubKey: string = ""
    for i in countup(0, pubKeyArg.len - 1, 2):
        pubKey = pubKey & ((char) parseHexInt(pubKeyArg[i .. i+1]))

    #Init the result.
    result = secp256k1_pubkey()
    #Parse the public key.
    if secp256k1_ec_pubkey_parse(
        context,
        addr result,
        cast[ptr cuchar](addr pubKey[0]),
        pubKey.len
    ) != 1:
        #If that failed...
        raise newException(ValueError, "Invalid Public Key.")

#Stringifies a public key.
proc `$!`*(pubKeyArg: secp256k1_pubkey): string {.raises: [ValueError].} =
    #Copy the pubKey arg, set the output, length, and create a byte array.
    var
        pubKey: secp256k1_pubkey = pubKeyArg
        len: csize = 33
        bytes: array[33, char]

    #Serialize the public key in a compressed format.
    if secp256k1_ec_pubkey_serialize(
        context,
        addr bytes[0],
        addr len,
        addr pubKey,
        SECP256K1_EC_COMPRESSED
    ) != 1:
        #If that failed...
        raise newException(ValueError, "Invalid Public Key.")

    #Init the result.
    result = ""
    #Turn the byte array into a hex string.
    for i in 0 ..< bytes.len:
        result = result & bytes[i].toHex()

#Generates a signature from a hex string.
proc secpSignature(sigArg: string): secp256k1_ecdsa_signature {.raises: [ValueError].} =
    #Turn the hex string into a byte array.
    var sig: string = ""
    for i in countup(0, sigArg.len - 1, 2):
        sig = sig & ((char) parseHexInt(sigArg[i .. i+1]))

    #Init the result.
    result = secp256k1_ecdsa_signature()
    #Parse the signature.
    if secp256k1_ecdsa_signature_parse_compact(
        context,
        addr result,
        cast[ptr cuchar](addr sig[0])
    ) != 1:
        #If that failed...
        raise newException(ValueError, "Invalid Signature.")

#Stringifies a signature.
proc `$`(sigArg: secp256k1_ecdsa_signature): string {.raises: [ValueError].} =
    #Copy the sig arg, make a byte array...
    var
        sig: secp256k1_ecdsa_signature = sigArg
        bytes: array[64, cuchar]

    #Serialize the signature in the compact format.
    if secp256k1_ecdsa_signature_serialize_compact(
        context,
        addr bytes[0],
        addr sig
    ) != 1:
        #If that failed...
        raise newException(ValueError, "Invalid Signature.")

    #Turn the byte array into a hex string.
    result = ""
    for i in 0 ..< bytes.len:
        result = result & bytes[i].toHex()

#Sign a message (hash).
proc secpSign*(privKeyArg: array[32, uint8], hashArg: string): string {.raises: [ValueError].} =
    #Copy the args, init the signature.
    var
        privKey: array[32, uint8] = privKeyArg
        hash: string = hashArg
        sig: secp256k1_ecdsa_signature = secp256k1_ecdsa_signature()

    #Sign the message,
    if secp256k1_ecdsa_sign(
        context,
        addr sig,
        cast[ptr cuchar](addr hash[0]),
        cast[ptr cuchar](addr privKey),
        nil,
        nil
    ) != 1:
        #If that failed...
        raise newException(ValueError, "Couldn't sign the following hash: " & hashArg & ".")

    #Set the result to the stringified signature.
    result = $sig

#Verify a signature.
proc secpVerify*(pubKeyArg: secp256k1_pubkey, hashArg: string, sigArg: string): bool =
    #Copy the args and create a sig object from the passed in stringified sig.
    var
        hash: string = hashArg
        pubKey: secp256k1_pubkey = pubKeyArg
        sig: secp256k1_ecdsa_signature = secpSignature(sigArg)

    #Verify the signature. If this function worked, returned true.
    result = secp256k1_ecdsa_verify(
        context,
        addr sig,
        cast[ptr cuchar]((cstring) hash),
        addr pubKey
    ) == 1
