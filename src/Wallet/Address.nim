#Number libs.
import ../lib/BN
import ../lib/Hex
import ../lib/Base58

#Hash lib.
import ../lib/SHA512 as SHA512File

#Public Key lib.
import PublicKey

#Generates a checksum for the public key.
#The checksum is the Base58 version of the concatenated 10th, 18th, 26th, 34th, 42nd, 50th, 58th, and 66th key characters.
proc generateChecksum(key: string): string =
    result = Base58.convert(
        Hex.revert(
            key[9] & key[17] & key[25] & key[33] & key[41] & key[49] & key[57] & key[65]
        )
    )

#Generates an address based on a public key.
#An address is composed of the following:
#   1. "Emb" prefix.
#   2. Base58 encoded version of the first 78 characters of the SHA512 cubed SHA512(SHA512(SHA512(key))) hash.
#   3. A checksum (described above).
#The Emb prefix is for easy identification.
#The SHA512 cubed hash is for security, and the 78 characters bit is to lower the address length from ~90 to ~60 (post Base58 encoding).
#The checksum, which only comments on what public key it's valid with, not if the address is valid, is in case of a 80/128 character hash collision.
#Finally, if the address (not including the Emb prefix):
#   A: Less than 57 characters, 0s are prefixed to it.
#   B: Greater than 61, the first character(s) are removed until it's 61.
#This is a really poor secondary checksum/safety buffer which makes the address between 60 and 64 characters, with the prefix.
proc newAddress*(key: string): string {.raises: [ValueError, OverflowError, Exception].} =
    if (key.len != 66):
        raise newException(ValueError, "Public Key isn't compressed.")

    #Base58 encoded version of the first 78 characters, and append the checksum of the key.
    result = Base58.convert(
        Hex.revert(
            ((SHA512^3)(key)).substr(0, 77)
        )
    ) & generateChecksum(key)

    while result.len < 57:
        result = "0" & result

    if result.len > 61:
        result = result.substr(result.len - 61, result.len)

    result = "Emb" & result

#Work with Public Keys objects, not just hex public keys.
proc newAddress*(key: PublicKey): string =
    result = newAddress($key)

#Verifies if an address is valid.
proc verify*(address: string): bool =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, 2) != "Emb":
        result = false
        return

    #Check the lengths.
    if address.len < 60:
        result = false
        return
    if address.len > 64:
        result = false
        return

    #Check to make sure it's a valid Base58 number, if there's no prefix.
    if not Base58.verify(address.substr(3, address.len)):
        result = false

#If we have a key to check with, make an address for that key and compare with the given address.
proc verify*(address: string, key: string): bool {.raises: [ValueError, OverflowError, Exception].} =
    result = address == newAddress(key)

#Work with Public Keys objects, not just hex public keys.
proc verify*(address: string, key: PublicKey): bool {.raises: [ValueError, OverflowError, Exception].} =
    return verify(address, $key)
