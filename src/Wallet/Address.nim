#Errors lib.
import ../lib/Errors

#Util lib (used for parseHexInt).
import ../lib/Util

#Ed25519 lib (for the Public Key object).
import Ed25519

#Base32 lib (used to encode the Address).
import ../lib/Base32

#Seq utils standard lib (used for concat).
import sequtils

#Human readable data.
const ADDRESS_HRP {.strdefine.}: string = "Mr"

#Expands the HRP.
func expandHRP(): seq[uint8] {.compileTime.} =
    result = @[]
    for c in ADDRESS_HRP:
        result.add(uint8(int(c) shr 5))
    result.add(0)
    for c in ADDRESS_HRP:
        result.add(uint8(int(c) and 31))

#Expanded HRP.
const HRP: seq[uint8] = expandHRP()

#Hex constants used for the BCH code.
const BCH_VALUES: array[5, uint32] = [
    uint32(0x3b6a57b2),
    uint32(0x26508e6d),
    uint32(0x1ea119fa),
    uint32(0x3d4233dd),
    uint32(0x2a1462b3)
]

#BCH Polymod function.
func polymod(
    values: seq[uint8]
): uint32 {.forceCheck: [].} =
    result = 1
    var b: uint32
    for value in values:
        b = result shr 25
        result = ((result and 0x01ffffff) shl 5) xor value
        for i in 0 ..< 5:
            if ((b shr i) and 1) == 1:
                result = result xor BCH_VALUES[i]


#Generates a BCH code.
func generateBCH(
    data: seq[uint8]
): seq[uint8] {.forceCheck: [].} =
    let polymod: uint32 = polymod(
        HRP
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

#Verifies a BCH code via a data argument of the Public Key and BCH code.
func verifyBCH(
    data: seq[uint8]
): bool {.inline, forceCheck: [].} =
    polymod(HRP.concat(data)) == 1

#Generates a address, using a modified form of Bech32 based on a public key.
#An address is composed of the following:
#   1. "Meros" prefix (human readable data part).
#   2. Base32 version of the public key.
#   3. A BCH code.
func newAddress(
    key: openArray[uint8]
): string {.forceCheck: [].} =
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
func newAddress*(
    keyArg: string
): string {.forceCheck: [
    EdPublicKeyError
].} =
    #Verify the key length.
    if (keyArg.len != 32) and (keyArg.len != 64):
        raise newException(EdPublicKeyError, "Invalid length Public Key passed to newAddress.")

    #Extract the key.
    var key: array[32, uint8]
    #If it's binary formatted...
    if keyArg.len == 32:
        for i in 0 ..< 32:
            key[i] = uint8(keyArg[i])
    #If it's hex formatted...
    else:
        try:
            for i in countup(0, 63, 2):
                key[i div 2] = uint8(parseHexInt(keyArg[i .. i + 1]))
        except ValueError:
            raise newException(EdPublicKeyError, "Hex-length Public Key with invalid Hex data passed to newAddress.")

    #Create a new address with the array.
    result = newAddress(key)

#Work with Public Keys objects, not just arrays.
func newAddress*(
    key: EdPublicKey
): string {.inline, forceCheck: [].} =
    newAddress(cast[array[32, uint8]](key))

#Checks if an address is valid.
func isValid*(
    address: string
): bool {.forceCheck: [].} =
    #Return true if there's no issue.
    result = true

    #Check for the prefix.
    if address.substr(0, ADDRESS_HRP.len - 1) != ADDRESS_HRP:
        return false
    #Check to make sure it's a valid Base32 number.
    if not address.substr(ADDRESS_HRP.len, address.len).isBase32():
        return false

    #Verify the BCH.
    var base32: seq[uint8]
    try:
        base32 = cast[seq[uint8]](
            address.substr(
                ADDRESS_HRP.len,
                address.len
            ).toBase32()
        )
    except ValueError:
        return false

    if not verifyBCH(base32):
        return false

#If we have a key to check against, check the address is valid, and that it matches the address for that key.
func isValid*(
    address: string,
    key: EdPublicKey
): bool {.inline, forceCheck: [].} =
    (address.isValid) and (address == newAddress(key))

#Converts an address to a string of its PublicKey.
func toPublicKey*(
    address: string
): string {.forceCheck: [
    AddressError
].} =
    #Verify the address.
    if not address.isValid():
        raise newException(AddressError, "Invalid Address passed to toPublicKey.")

    #Get the key by removing the HRP. removing the BCH code, converting the string to Base32, and the Base32 to Base256.
    var key: seq[uint8]
    try:
        key = address.substr(ADDRESS_HRP.len, address.len - 7).toBase32().toSeq()
    except ValueError:
        #toBase32 will throw a ValueError if there's a problem.
        #That said, the validity check guarantees there isn't one.
        #Raise an error, but with a custom message that explains how messed up this is.
        raise newException(AddressError, "The address we're trying to get the Public Key of is invalid, despite isValid returning true.")

    #Turn the seq into a string.
    for c in key:
        result &= char(c)
