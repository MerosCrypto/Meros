#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritRemoval object.
import ../../../Database/Consensus/objects/MeritRemovalObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse ELement libs.
import ParseVerification

#Parse an Element.
proc parseElement(
    elem: string,
    holder: string,
    i: int
): tuple[
    element: Element,
    len: int
] {.forceCheck: [
    ValueError,
    BLSError
].} =
    case int(elem[i]):
        of VERIFICATION_PREFIX:
            result.len = VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
            if elem.len < result.len + i:
                raise newException(ValueError, "ParseMeritRemoval's parseElement not handed enough data to get an Element.")

            try:
                result.element = parseVerification(holder & elem[i + 1 ..< i + 1 + result.len])
                inc(result.len)
            except ValueError as e:
                fcRaise e
            except BLSError as e:
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
    #BLS Public Key | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
    var
        mrSeq: seq[string] = mrStr.deserialize(
            BLS_PUBLIC_KEY_LEN,
            BYTE_LEN
        )
        partial: bool

        i: int = BLS_PUBLIC_KEY_LEN + BYTE_LEN
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
    #BLS Public Key | Partial | Element Prefix | Serialized Element without Holder | Element Prefix | Serialized Element without Holder
    var
        mrSeq: seq[string] = mrStr.deserialize(
            BLS_PUBLIC_KEY_LEN,
            BYTE_LEN
        )
        partial: bool

        i: int = BLS_PUBLIC_KEY_LEN + BYTE_LEN
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
            partial,
            element1,
            element2,
            newBLSSignature(mrStr[mrStr.len - 96 ..< mrStr.len])
        )
    except BLSError as e:
        fcRaise e
