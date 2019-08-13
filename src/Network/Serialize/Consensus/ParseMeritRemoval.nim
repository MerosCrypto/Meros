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
            BYTE_LEN,
            BYTE_LEN
        )
        partial: bool
        e1Len: int
        element1: Element
        element2: Element

    case int(mrSeq[1][0]):
        of 0:
            partial = false
        of 1:
            partial = true
        else:
            raise newException(ValueError, "MeritRemoval has an invalid partial field.")

    case int(mrSeq[2][0]):
        of VERIFICATION_PREFIX:
            e1Len = VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
            if mrStr.len < MERIT_REMOVAL_LENS[0] + e1Len + 1:
                raise newException(ValueError, "parseMeritRemoval not handed enough data to get the first Element.")
            try:
                element1 = parseVerification(mrSeq[0] & mrStr[MERIT_REMOVAL_LENS[0] ..< MERIT_REMOVAL_LENS[0] + e1Len])
            except ValueError as e:
                fcRaise e
            except BLSError as e:
                fcRaise e

        else:
            raise newException(ValueError, "parseMeritRemoval tried to parse an invalid Element type")

    case int(mrStr[MERIT_REMOVAL_LENS[0] + e1Len]):
        of VERIFICATION_PREFIX:
            if mrStr.len < MERIT_REMOVAL_LENS[0] + e1Len + VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN:
                raise newException(ValueError, "parseMeritRemoval not handed enough data to get the second Element.")
            try:
                element2 = parseVerification(mrSeq[0] & mrStr[MERIT_REMOVAL_LENS[0] + e1Len + BYTE_LEN ..< MERIT_REMOVAL_LENS[0] + e1Len + BYTE_LEN + VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN])
            except ValueError as e:
                fcRaise e
            except BLSError as e:
                fcRaise e

        else:
            raise newException(ValueError, "parseMeritRemoval tried to parse an invalid Element type.")

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
            BYTE_LEN,
            BYTE_LEN
        )
        partial: bool
        e1Len: int
        element1: Element
        element2: Element

    case int(mrSeq[1][0]):
        of 0:
            partial = false
        of 1:
            partial = true
        else:
            raise newException(ValueError, "MeritRemoval has an invalid partial field.")

    case int(mrSeq[2][0]):
        of VERIFICATION_PREFIX:
            e1Len = VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN
            if mrStr.len < MERIT_REMOVAL_LENS[0] + e1Len + 1:
                raise newException(ValueError, "parseMeritRemoval not handed enough data to get the first Element.")
            try:
                element1 = parseVerification(mrSeq[0] & mrStr[MERIT_REMOVAL_LENS[0] ..< MERIT_REMOVAL_LENS[0] + e1Len])
            except ValueError as e:
                fcRaise e
            except BLSError as e:
                fcRaise e

        else:
            raise newException(ValueError, "parseMeritRemoval tried to parse an invalid Element type")

    case int(mrStr[MERIT_REMOVAL_LENS[0] + e1Len]):
        of VERIFICATION_PREFIX:
            if mrStr.len < MERIT_REMOVAL_LENS[0] + e1Len + VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN:
                raise newException(ValueError, "parseMeritRemoval not handed enough data to get the second Element.")
            try:
                element2 = parseVerification(mrSeq[0] & mrStr[MERIT_REMOVAL_LENS[0] + e1Len + BYTE_LEN ..< MERIT_REMOVAL_LENS[0] + e1Len + BYTE_LEN + VERIFICATION_LEN - BLS_PUBLIC_KEY_LEN])
            except ValueError as e:
                fcRaise e
            except BLSError as e:
                fcRaise e

        else:
            raise newException(ValueError, "parseMeritRemoval tried to parse an invalid Element type.")

    #Create the MeritRemoval.
    try:
        result = newSignedMeritRemovalObj(
            partial,
            element1,
            element2,
            newBLSSignature(mrStr[mrStr.len - 96 ..< mrStr.len])
        )
    except BLSError as e:
        fcRaise e
