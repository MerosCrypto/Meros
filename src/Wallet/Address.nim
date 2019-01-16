#Numerical libs.
import BN
import ../lib/Base

#ED25519 lib (for the Public Key object).
import ../lib/ED25519

#Base32 lib.
import ../lib/Base32

#String utils standard lib.
import strutils

#Seq utils standard lib.
import sequtils

#Human readable data.
const ADDRESS_HRP {.strdefine.}: string = "Meros"

#Hex constants used for the BCH code.
const BCH_VALUES: array[5, uint32] = [
    uint32(0x3b6a57b2),
    uint32(0x26508e6d),
    uint32(0x1ea119fa),
    uint32(0x3d4233dd),
    uint32(0x2a1462b3)
]

#BCH Polymod function.
func polymod(values: seq[uint8]): uint32 {.raises: [].} =
    result = 1
    var b: uint32
    for value in values:
        b = result shr 25
        result = ((result and 0x1ffffff) shl 5) xor value
        for i in 0 .. 4:
            if ((b shr i) and 1) == 1:
                result = result xor BCH_VALUES[i]
            else:
                result = result xor 0

#Expands the HRP.
#This could a const of sorts but then we can't use func.
#It's better this way.
func expandHRP(): seq[uint8] =
    result = @[]
    for c in ADDRESS_HRP:
        result.add(uint8(ord(c) shr 5))
    result.add(0)
    for c in ADDRESS_HRP:
        result.add(uint8(ord(c) and 31))

#Generates a BCH code.
func generateBCH*(data: seq[uint8]): seq[uint8] {.raises: [].} =
    let polymod: uint32 = polymod(
        expandHRP()
        .concat(data)
        .concat(@[
            uint8(0),
            uint8(0),
            uint8(0),
            uint8(0),
            uint8(0),
            uint8(0)
        ])
    ) xor 1

    result = @[]
    for i in 0 .. 5:
        result.add(
            uint8((polymod shr (5 * (5 - i))) and 31)
        )

#Verifies a BCH code by taking in the HRP and data (with the BCH code in the data).
func verifyBCH(data: seq[uint8]): bool {.raises: [].} =
    polymod(expandHRP().concat(data)) == 1

#Generates a address using a modified form of Bech32 based on a public key.
#An address is composed of the following:
#   1. "Meros" prefix (human readable data part).
#   2. Base32 version of the public key.
#   3. A BCH code.
func newAddress*(key: openArray[uint8]): string {.raises: [ValueError].} =
    #Verify the key length.
    if key.len != 32:
        raise newException(ValueError, "Public Key isn't the proper length.")

    #Get the Base32 version of Public Key.
    let base32: Base32 = key.toBase32()

    #Create the address.
    result =
        ADDRESS_HRP &
        $base32 &
        $cast[Base32](
            generateBCH(
                cast[seq[uint8]](base32)
            )
        )

#Work with binary/hex strings, not just arrays.
func newAddress*(keyArg: string): string {.raises: [ValueError].} =
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
func newAddress*(key: EdPublicKey): string {.raises: [ValueError].} =
    result = newAddress(cast[array[32, uint8]](key))

#Verifies if an address is valid.
func verify*(address: string): bool {.raises: [ValueError].} =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, ADDRESS_HRP.len - 1) != ADDRESS_HRP:
        return false

    #Check to make sure it's a valid Base32 number.
    if not address.substr(ADDRESS_HRP.len, address.len).isBase32():
        return false

    #Verify the BCH.
    if not verifyBCH(
        cast[seq[uint8]](
            address.substr(
                ADDRESS_HRP.len,
                address.len
            ).toBase32()
        )
    ):
        return false

#If we have a key to check with, make an address for that key and compare with the given address.
func verify*(address: string, key: EdPublicKey): bool {.raises: [ValueError].} =
    address == newAddress(key)

#Converts an address to a BN.
func toBN*(address: string): BN {.raises: [ValueError].} =
    #Verify the address.
    if not address.verify():
        raise newException(ValueError, "Invalid Address.")

    var
        #Get the key by removing the HRP. removing the BCH code, converting the string to Base32, and the Base32 to Base256.
        key: seq[uint8] = address.substr(ADDRESS_HRP.len, address.len - 7).toBase32().toSeq()
        keyStr: string = ""

    #Turn the seq into a string.
    for c in key:
        keyStr &= char(c)

    #Create the BN.
    result = keyStr.toBN(256)
