#RNG lib.
import ../lib/RandomWrapper

#SECP256K1 lib.
import ../lib/SECP256K1Wrapper

#Custom Errors.
import ../lib/Errors

#string utils standard lib.
import strutils

#Private Key type.
type PrivateKey* = array[32, cuchar]

#Creates a new Private Key.
proc newPrivateKey*(): PrivateKey {.raises: [ResultError, Exception].} =
    #Run a max of ten times.
    for _ in 0 ..< 10:
        #Generate a random 256 bit key.
        random(cast[ptr array[0, uint8]](addr result), 32)
        #If the SECP256K1 lib says it's valid...
        if secpPrivateKey(result):
            #Return.
            return

    #If we never made a valid key, which should never happen, throw a Result Error.
    raise newException(ResultError, "Couldn't generate a valid Private Key.")

#Create a new PrivateKey based on a hex string.
proc newPrivateKey*(hex: string): PrivateKey {.raises: [ValueError].} =
    #Parse the hex string.
    for i in countup(0, 63, 2):
        result[i div 2] = cuchar(parseHexInt(hex[i .. i + 1]))

    #If it's an invalid key, throw an error.
    if secpPrivateKey(result) == false:
        raise newException(ValueError, "Private Key is invalid.")

#Stringify a private key.
proc `$`*(key: PrivateKey): string {.raises: [].} =
    result = ""
    for i in 0 ..< 32:
        result = result & key[i].toHex()

#Sign a message via its hash.
proc sign*(key: PrivateKey, hash: string): string {.raises: [ValueError].} =
    result = key.secpSign(hash)
