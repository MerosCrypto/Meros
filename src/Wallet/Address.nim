#Errors lib.
import ../lib/Errors

#Util lib (used for parseHexInt).
import ../lib/Util

#Seq utils standard lib.
import sequtils

#String utils standard lib.
import strutils

#Human readable data.
const ADDRESS_HRP {.strdefine.}: string = "mr"

#Expands the HRP.
func expandHRP(): seq[byte] {.compileTime.} =
    result = @[]
    for c in ADDRESS_HRP:
        result.add(byte(int(c) shr 5))
    result.add(0)
    for c in ADDRESS_HRP:
        result.add(byte(int(c) and 31))

#Expanded HRP.
const HRP: seq[byte] = expandHRP()

#Base32 characters.
const CHARACTERS: string = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

#Hex constants used for the BCH code.
const BCH_VALUES: array[5, uint32] = [
    uint32(0X3B6A57B2),
    uint32(0X26508E6D),
    uint32(0X1EA119FA),
    uint32(0X3D4233DD),
    uint32(0X2A1462B3)
]

#BCH Polymod function.
func polymod(
    values: seq[byte]
): uint32 {.forceCheck: [].} =
    result = 1
    var b: uint32
    for value in values:
        b = result shr 25
        result = ((result and 0x01FFFFFF) shl 5) xor value
        for i in 0 ..< 5:
            if ((b shr i) and 1) == 1:
                result = result xor BCH_VALUES[i]


#Generates a BCH code.
func generateBCH(
    data: seq[byte]
): seq[byte] {.forceCheck: [].} =
    let polymod: uint32 = polymod(
        HRP
        .concat(data)
        .concat(@[
            byte(0),
            byte(0),
            byte(0),
            byte(0),
            byte(0),
            byte(0)
        ])
    ) xor 1

    result = @[]
    for i in 0 ..< 6:
        result.add(
            byte((polymod shr (5 * (5 - i))) and 31)
        )

#Verifies a BCH code via a data argument of the Public Key and BCH code.
func verifyBCH(
    data: seq[byte]
): bool {.inline, forceCheck: [].} =
    polymod(HRP.concat(data)) == 1

#Convert between two bases.
func convert(
    data: seq[byte],
    fromBits: int,
    to: int,
    pad: bool
): seq[byte] {.forceCheck: [].} =
    var
        acc: int = 0
        bits: int = 0
    let
        maxv: int = (1 shl to) - 1
        max_acc: int = (1 shl (fromBits + to - 1)) - 1

    for value in data:
        acc = ((acc shl fromBits) or int(value)) and max_acc
        bits += fromBits
        while bits >= to:
            bits -= to
            result.add(byte((acc shr bits) and maxv))

    if pad and (bits > 0):
        result.add(byte((acc shl (to - bits)) and maxv))

#Create a new address.
func newAddress*(
    dataArg: string
): string {.forceCheck: [].} =
    result = ADDRESS_HRP & "1"
    var
        data: seq[byte] = convert(cast[seq[byte]](dataArg), 8, 5, true)
        encoded: seq[byte] = data.concat(generateBCH(data))
    for c in encoded:
        result &= CHARACTERS[c]

#Checks if an address is valid.
func isValidAddress*(
    address: string
): bool {.forceCheck: [].} =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, ADDRESS_HRP.len).toLower() != ADDRESS_HRP & "1":
        return false
    #Check the length.
    if (address.len < ADDRESS_HRP.len + 6) or (90 < address.len):
        return false
    #Make sure it's all in one case.
    if (address.toLower() != address) and (address.toUpper() != address):
        return false
    #Check to make sure it's a valid Base32 number.
    for c in address.substr(ADDRESS_HRP.len + 1, address.len).toLower():
        #If the character is not in the character set...
        if CHARACTERS.find(c) == -1:
            return false
    #Check the BCH code.
    var
        dataStr: string = address.substr(ADDRESS_HRP.len + 1, address.len).toLower()
        data: seq[byte] = @[]
    for c in dataStr:
        data.add(byte(CHARACTERS.find(c)))
    if not verifyBCH(data):
        return false

#Get the data encoded in an address.
proc getEncodedData*(
    address: string
): seq[byte] {.forceCheck: [
    ValueError
].} =
    if not address.isValidAddress():
        raise newLoggedException(ValueError, "Invalid address.")

    var data: string = address.substr(ADDRESS_HRP.len + 1, address.len).toLower()
    for c in 0 ..< data.len - 6:
        result.add(byte(CHARACTERS.find(data[c])))
    result = convert(result, 5, 8, false)
