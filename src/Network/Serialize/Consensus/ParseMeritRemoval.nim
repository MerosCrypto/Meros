#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritRemoval object.
import ../../../Database/Consensus/Elements/objects/MeritRemovalObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse ELement libs.
import ParseVerification
import ParseVerificationPacket

#Parse an Element.
proc parseElement(
    mr: string,
    holder: string,
    i: int
): tuple[
    element: Element,
    len: int
] {.forceCheck: [
    ValueError
].} =
    case int(mr[i]):
        of VERIFICATION_PREFIX:
            result.len = VERIFICATION_LEN - NICKNAME_LEN
            if mr.len < result.len + i:
                raise newException(ValueError, "ParseMeritRemoval's parseElement not handed enough data to get a Verification.")

            try:
                inc(result.len)
                result.element = parseVerification(holder & mr[i + 1 ..< i + result.len])
            except ValueError as e:
                fcRaise e

        of VERIFICATION_PACKET_PREFIX:
            result.len = VERIFICATION_PACKET_LENS[0]
            if mr.len < result.len + i:
                raise newException(ValueError, "ParseMeritRemoval's parseElement not handed enough data to get a Verification Packet's verifiers length.")

            var verifiers: int = mr[i + 1 ..< i + 1 + result.len].fromBinary()
            result.len += (VERIFICATION_PACKET_LENS[1] * verifiers) + VERIFICATION_PACKET_LENS[2]
            if mr.len < result.len + i:
                raise newException(ValueError, "ParseMeritRemoval's parseElement not handed enough data to get a Verification Packet's verifiers/hash.")

            try:
                inc(result.len)
                result.element = parseVerificationPacket(mr[i + 1 ..< i + result.len])
            except ValueError as e:
                fcRaise e

        else:
            raise newException(ValueError, "ParseMeritRemoval's parseElement tried to parse an invalid/unsupported Element type")

#Parse a MeritRemoval.
proc parseMeritRemoval*(
    mrStr: string
): MeritRemoval {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Holder's Nickname | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
    var
        mrSeq: seq[string] = mrStr.deserialize(
            NICKNAME_LEN,
            BYTE_LEN
        )
        partial: bool

        i: int = NICKNAME_LEN + BYTE_LEN
        peResult: tuple[
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
        peResult = mrStr.parseElement(mrSeq[0], i)
        i += peResult.len
        element1 = peResult.element
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    try:
        peResult = mrStr.parseElement(mrSeq[0], i)
        element2 = peResult.element
    except ValueError as e:
        fcRaise e
    except BLSError as e:
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
    ValueError,
    BLSError
].} =
    #Holder's Nickname | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
    var
        mrSeq: seq[string] = mrStr.deserialize(
            NICKNAME_LEN,
            BYTE_LEN
        )
        partial: bool

        i: int = NICKNAME_LEN + BYTE_LEN
        peResult: tuple[
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
        peResult = mrStr.parseElement(mrSeq[0], i)
        i += peResult.len
        element1 = peResult.element
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    try:
        peResult = mrStr.parseElement(mrSeq[0], i)
        element2 = peResult.element
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the SignedMeritRemoval.
    try:
        result = newSignedMeritRemovalObj(
            uint16(mrSeq[0].fromBinary()),
            partial,
            element1,
            element2,
            newBLSSignature(mrStr[mrStr.len - 96 ..< mrStr.len])
        )
    except BLSError as e:
        fcRaise e
