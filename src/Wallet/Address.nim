#Number libs.
import ../lib/BN
import ../lib/Base

#Hash lib.
import ../lib/SHA512 as SHA512File

#Public Key lib.
import PublicKey

#Generates a checksum for the public key.
#The checksum is the last 4 characters of the Base58 version of the SHA512 cubed hash of the key.
proc generateChecksum(key: string): string {.raises: [Exception].} =
    result =
        (SHA512^3)(
            key.toBN(16).toString(256)
        )
        .toBN(16)
        .toString(58)
    result = result.substr(result.len - 4, result.len)

#Generates an address based on a public key.
#An address is composed of the following:
#   1. "Emb" prefix.
#   2. Base58 encoded version of the public key.
#   3. A checksum (described above).
#The Emb prefix is for easy identification.
#The public key is because we need it; Base58 encoding is to save space.
#The checksum is to verify the user typed a valid address.
proc newAddress*(key: string): string {.raises: [ValueError, Exception].} =
    if (key.len != 66):
        raise newException(ValueError, "Public Key isn't compressed.")

    #Base58 encoded version of the compressed public key, plus a checksum of said public key.
    result =
        key
        .toBN(16)
        .toString(58) &
        generateChecksum(key)

    #Add the EMB prefix.
    result = "Emb" & result

#Work with Public Keys objects, not just hex public keys.
proc newAddress*(key: PublicKey): string {.raises: [ ValueError, Exception].} =
    result = newAddress($key)

#Verifies if an address is valid.
proc verify*(address: string): bool {.raises: [ValueError, Exception].} =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, 2) != "Emb":
        result = false
        return

    #Check to make sure it's a valid Base58 number.
    if not address.substr(3, address.len).isBase(58):
        result = false
        return

    #Verify the public key format.
    let key: string = address.substr(3, address.len-5).toBN(58).toString(16)
    if (key.substr(0, 1) != "02") and (key.substr(0, 1) != "03"):
        result = false
        return

    #Verify the checksum.
    if address.substr(address.len-4, address.len) != generateChecksum(key):
        result = false
        return

#If we have a key to check with, make an address for that key and compare with the given address.
proc verify*(address: string, key: string): bool {.raises: [ValueError, Exception].} =
    address == newAddress(key)

#Work with Public Keys objects, not just hex public keys.
proc verify*(address: string, key: PublicKey): bool {.raises: [ValueError, Exception].} =
    verify(address, $key)

proc toBN*(address: string): BN {.raises: [ValueError, Exception].} =
    if not verify(address):
        raise newException(ValueError, "Invalid Address.")

    result = address.substr(3, address.len-5).toBN(58)

proc toBN*(address: PublicKey): BN {.raises: [ValueError, Exception].} =
    toBN(newAddress(address))
