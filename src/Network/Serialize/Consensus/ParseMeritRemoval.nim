#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritRemoval object.
import ../../../Database/Consensus/Elements/objects/MeritRemovalObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse Element libs.
import ParseElement
import ParseVerification
import ParseVerificationPacket

#Parse an Element in a MeritRemoval.
proc parseMeritRemovalElement(
    data: string,
    i: int,
    holder: string = ""
): tuple[
    element: Element,
    len: int
] {.forceCheck: [
    ValueError
].} =
    try:
        result.len = data.getLength(
            {
                int8(VERIFICATION_PREFIX),
                int8(VERIFICATION_PACKET_PREFIX),
                int8(SEND_DIFFICULTY_PREFIX),
                int8(DATA_DIFFICULTY_PREFIX),
                int8(GAS_PRICE_PREFIX)
            },
            i,
            holder
        )

        case int(data[i]):
            of VERIFICATION_PREFIX:
                result.element = parseVerification(holder & data[i + 1 ..< i + result.len])
            of VERIFICATION_PACKET_PREFIX:
                result.element = parseMeritRemovalVerificationPacket(data[i + 1 ..< i + result.len])
            else:
                raise newException(ValueError, "parseMeritRemovalElement tried to parse an invalid/unsupported Element type.")
    except ValueError as e:
        fcRaise e

#Parse a MeritRemoval.
proc parseMeritRemoval*(
    mrStr: string
): MeritRemoval {.forceCheck: [
    ValueError
].} =
    #Holder's Nickname | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
    var
        mrSeq: seq[string] = mrStr.deserialize(
            NICKNAME_LEN,
            BYTE_LEN
        )
        partial: bool

        pmreResult: tuple[
            element: Element,
            len: int
        ]
        i: int = NICKNAME_LEN + BYTE_LEN

        element1: Element
        element2: Element

    if mrSeq[1].len != 1:
        raise newException(ValueError, "MeritRemoval not handed enough data to get if it's partial.")
    case int(mrSeq[1][0]):
        of 0:
            partial = false
        of 1:
            partial = true
        else:
            raise newException(ValueError, "MeritRemoval has an invalid partial field.")

    try:
        pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
        i += pmreResult.len
        element1 = pmreResult.element
    except ValueError as e:
        fcRaise e

    try:
        pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
        element2 = pmreResult.element
    except ValueError as e:
        fcRaise e

    #Create the MeritRemoval.
    result = newMeritRemovalObj(
        uint16(mrSeq[0].fromBinary()),
        partial,
        element1,
        element2
    )

#Parse a Signed MeritRemoval.
proc parseSignedMeritRemoval*(
    mrStr: string
): SignedMeritRemoval {.forceCheck: [
    ValueError
].} =
    #Holder's Nickname | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
    var
        mrSeq: seq[string] = mrStr.deserialize(
            NICKNAME_LEN,
            BYTE_LEN
        )
        partial: bool

        i: int = NICKNAME_LEN + BYTE_LEN
        pmreResult: tuple[
            element: Element,
            len: int
        ]

        element1: Element
        element2: Element

    if mrSeq[1].len != 1:
        raise newException(ValueError, "MeritRemoval not handed enough data to get if it's partial.")
    case int(mrSeq[1][0]):
        of 0:
            partial = false
        of 1:
            partial = true
        else:
            raise newException(ValueError, "MeritRemoval has an invalid partial field.")

    try:
        pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
        i += pmreResult.len
        element1 = pmreResult.element
    except ValueError as e:
        fcRaise e

    try:
        pmreResult = mrStr.parseMeritRemovalElement(i, mrSeq[0])
        element2 = pmreResult.element
    except ValueError as e:
        fcRaise e

    #Create the SignedMeritRemoval.
    try:
        result = newSignedMeritRemovalObj(
            uint16(mrSeq[0].fromBinary()),
            partial,
            element1,
            element2,
            newBLSSignature(mrStr[mrStr.len - BLS_SIGNATURE_LEN ..< mrStr.len])
        )
    except BLSError:
        raise newException(ValueError, "Invalid Signature.")
