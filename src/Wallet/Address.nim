import ../lib/BN
import ../lib/Hex
import ../lib/Base58
import ../lib/SHA512

#Generates a checksum for the public key.
#The checksum is the Base58 version of the concatenated 88th, 96th, 104th, 112th, 120th, and 127th key characters.
proc generateChecksum(key: string): string =
    result = Base58.convert(
        Hex.revert(
            key[88] & key[96] & key[104] & key[112] & key[120] & key[127]
        )
    )

#Generates an address based on a public key.
#An address is composed of the following:
#   1. "Emb" prefix.
#   2. Base58 encoded version of the first 80 characters of the SHA512 hash.
#   3. A checksum (described above).
#The Emb prefix is for easy identification.
#The SHA512 hash is for obscurity, and the 80 characters bit is to lower the address length from ~90 to ~60 (post Base58 encoding).
#The checksum, which only comments on what public key it's valid with, not if the address is valid, is in case of a 80/128 character hash collision.
#Finally, if the address (not including the Emb prefix):
#   A: Less than 57 characters, 0s are prefixed to it.
#   B: Greater than 61, the first character(s) are removed until it's 61.
#This is a really poor secondary checksum/safety buffer which makes the address between 60 and 64 characters, with the prefix.
proc newAddress*(key: string): string =
    #ase58 encoded version of the first 80 characters, and append the checksum of the key.
    result = Base58.convert(
        Hex.revert(
            SHA512(key).substr(0, 79)
        )
    ) & generateChecksum(key)

    while result.len < 57:
        result = "0" & result

    if result.len > 61:
        result = result.substr(result.len - 61, result.len)

    result = "Emb" & result

#Verifies if an address is valid.
proc verify*(address: string): bool =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, 2) != "Emb":
        echo "prefix\r\n\"" & address.substr(0, 2) & "\""
        result = false
        return

    #Check the lengths.
    if address.len < 60:
        echo "pre len"
        result = false
        return
    if address.len > 64:
        echo "post len"
        result = false
        return

    #Check to make sure it's a valid Base58 number, if there's no prefix.
    if not Base58.verify(address.substr(3, address.len)):
        echo "not b58"
        result = false

#If we have a key to check with, make an address for that key and compare with the given address.
proc verify*(address: string, key: string): bool =
    result = address == newAddress(key)
    if result == false:
        echo $address & " does not equal \r\n" & newAddress(key)
