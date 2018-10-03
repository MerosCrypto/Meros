#Numerical libs.
import BN
import ../lib/Base

#ED25519 lib (for the Public Key object).
import ../lib/ED25519

#Base32 lib.
import ../lib/Base32

#String utils standard lib.
import strutils

#Human readable data.
const HRP: string = "EMB"

#Generates a six character BCH code for the public key.
proc generateBCH(data: Base32): string =
    #Create the BCH.
    #TODO.
    result = ""

#Generates a address using a modified form of Bech32 based on a public key.
#An address is composed of the following:
#   1. "Emb" prefix (human readable data part).
#   2. Base32 version of the public key.
#   3. A BCH code.
proc newAddress*(key: openArray[uint8]): string {.raises: [ValueError].} =
    #Verify the key length.
    if key.len != 32:
        raise newException(ValueError, "Public Key isn't the proper length.")

    #Get the Base32 version of Public Key.
    let base32: Base32 = key.toBase32()

    #Create the address.
    result =
        "Emb" &
        $base32 &
        generateBCH(base32)

#Work with binary/hex strings, not just arrays.
proc newAddress*(keyArg: string): string {.raises: [ValueError].} =
    #Verify the key length.
    if (keyArg.len != 32) and (keyArg.len != 64):
        raise newException(ValueError, "Public Key isn't the proper length.")

    #Extract the key.
    var key: array[32, uint8]
    #If it's binary formatted...
    if keyArg.len == 32:
        for i in 0 ..< 32:
            key[i] = uint8(keyArg[i])
    #If it's hex formatted...
    else:
        for i in countup(0, 63, 2):
            key[i div 2] = uint8(parseHexInt(keyArg[i .. i + 1]))

    #Create a new address with the array.
    result = newAddress(key)

#Work with Public Keys objects, not just arrays.
proc newAddress*(key: PublicKey): string {.raises: [ValueError].} =
    result = newAddress(cast[array[32, uint8]](key))

#Verifies if an address is valid.
proc verify*(address: string): bool {.raises: [].} =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, 2) != "Emb":
        return false

    #Check to make sure it's a valid Base32 number.
    if not address.substr(3, address.len).isBase32():
        return false

    #Verify the BCH.
    #TODO.

#If we have a key to check with, make an address for that key and compare with the given address.
proc verify*(address: string, key: PublicKey): bool {.raises: [ValueError].} =
    address == newAddress(key)

proc toBN*(address: string): BN {.raises: [ValueError].} =
    #Verify the address.
    if not address.verify():
        raise newException(ValueError, "Invalid Address.")

    #Define the key and a string to put the array into.
    var
        key: seq[uint8] = address.substr(3, address.len).toBase32().toSeq()
        keyStr: string = ""

    #Turn the seq into a string.
    #We don't use b in key because Base32 is returning a trailing 0 for some reason.
    for i in 0 ..< 32:
        keyStr &= char(key[i])

    #Create the BN.
    result = keyStr.toBN(256)
