#ED25519 lib.
import ../lib/ED25519
#Export PrivateKey from ED25519.
export ED25519.PrivateKey

#Custom Errors.
import ../lib/Errors

#string utils standard lib.
import strutils

#Creates a new Private Key.
proc newPrivateKey*(): PrivateKey {.raises: [Exception].} =
    newKeyPair().priv

#Creates a new Private Key based on a string.
proc newPrivateKey*(key: string): PrivateKey {.raises: [ValueError].} =
    #If it's binary...
    if key.len == 64:
        for i in 0 ..< 64:
            result[i] = key[i]
    #If it's hex...
    elif key.len == 128:
        for i in countup(0, 127, 2):
            result[i div 2] = cuchar(parseHexInt(key[i .. i + 1]))
    else:
        raise newException(ValueError, "Invalid Private Key.")
#Stringify a Private Key.
proc `$`*(key: PrivateKey): string {.raises: [].} =
    result = ""
    for i in 0 ..< 64:
        result = result & uint8(key[i]).toHex()

#Sign a message.
proc sign*(key: PrivateKey, msg: string): string {.raises: [Exception].} =
    result = ED25519.sign(key, "EMB" & msg)
