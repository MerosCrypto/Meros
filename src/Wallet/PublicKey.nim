#ED25519.
import ../lib/ED25519
#Export PublicKey from ED25519.
export ED25519.PublicKey

#Private Key lib.
import PrivateKey

#String utils standard lib.
import strutils

#Create a new Public Key from a private key.
proc newPublicKey*(privKey: PrivateKey): PublicKey {.raises: [Exception].} =
    result = ED25519.newPublicKey(privKey)

#Create a new Public Key from a string.
proc newPublicKey*(key: string): PublicKey {.raises: [ValueError].} =
    #If it's binary...
    if key.len == 32:
        for i in 0 ..< 32:
            result[i] = key[i]
    #If it's hex...
    elif key.len == 64:
        for i in countup(0, 63, 2):
            result[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
    else:
        raise newException(ValueError, "Invalid Public Key.")

#Verify a signature using a constructed Public Key.
proc verify*(key: PublicKey, msg: string, sig: string): bool {.raises: [Exception].} =
    ED25519.verify(key, "EMB" & msg, sig)

#Stringify a Public Key to it's hex representation.
proc `$`*(key: PublicKey): string {.raises: [].} =
    result = ""
    for i in 0 ..< 32:
        result = result & uint8(key[i]).toHex()
