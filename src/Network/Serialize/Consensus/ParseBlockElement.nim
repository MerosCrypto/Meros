#Errors lib.
import ../../../lib/Errors

#Element object.
import ../../../Database/Consensus/Elements/objects/ElementObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse ELement libs.
import ParseElement
import ParseVerification
import ParseVerificationPacket
import ParseMeritRemoval

const BLOCK_ELEMENT_SET: set[int8] = {
    int8(SEND_DIFFICULTY_PREFIX),
    int8(DATA_DIFFICULTY_PREFIX),
    int8(GAS_PRICE_PREFIX),
    int8(MERIT_REMOVAL_PREFIX)
}

#Parse a BlockElement.
proc parseBlockElement*(
    data: string,
    i: int
): tuple[
    element: BlockElement,
    len: int
] {.forceCheck: [
    ValueError
].} =
    if not (int8(data[i]) in BLOCK_ELEMENT_SET):
        raise newException(ValueError, "parseBlockElement tried to parse an invalid/unsupported Element type.")

    try:
        result.len = data.getLength(BLOCK_ELEMENT_SET, i)
        case int(data[i]):
            of MERIT_REMOVAL_PREFIX:
                result.element = parseMeritRemoval(data[i + 1 ..< i + result.len])
            else:
                doAssert(false, "parseBlockElement tried to parse an unsupported Element despite having an existing if check.")
    except ValueError as e:
        fcRaise e
