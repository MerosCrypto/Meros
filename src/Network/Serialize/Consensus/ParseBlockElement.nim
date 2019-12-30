#Errors lib.
import ../../../lib/Errors

#Element object.
import ../../../Database/Consensus/Elements/objects/ElementObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse Element libs.
import ParseElement
import ParseDataDifficulty
import ParseMeritRemoval

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
    try:
        result.len = BLOCK_ELEMENT_SET.getLength(data[i])

        if int(data[i]) == MERIT_REMOVAL_PREFIX:
            for _ in 0 ..< 2:
                var
                    holdersLen: int = 0
                    holders: int = 0
                if int(data[i + result.len]) == VERIFICATION_PACKET_PREFIX:
                    holdersLen = {
                        int8(VERIFICATION_PACKET_PREFIX)
                    }.getLength(data[i + result.len])
                    holders = data[i + result.len + 1 .. i + result.len + holdersLen].fromBinary()

                result.len += MERIT_REMOVAL_ELEMENT_SET.getLength(
                    data[i + result.len],
                    holders,
                    MERIT_REMOVAL_PREFIX
                ) + holdersLen
    except ValueError as e:
        raise e

    if i + result.len > data.len:
        raise newException(ValueError, "parseBlockElement not handed enough data to parse the next Element.")

    try:
        case int(data[i]):
            of SEND_DIFFICULTY_PREFIX:
                doAssert(false, "SendDifficulties are not supported.")
            of DATA_DIFFICULTY_PREFIX:
                result.element = parseDataDifficulty(data[i + 1 .. i + result.len])
            of GAS_PRICE_PREFIX:
                doAssert(false, "GasPrices are not supported.")
            of MERIT_REMOVAL_PREFIX:
                result.element = parseMeritRemoval(data[i + 1 .. i + result.len])
            else:
                doAssert(false, "Possible Element wasn't supported.")
    except ValueError as e:
        raise e

    if int(data[i]) != MERIT_REMOVAL_PREFIX:
        inc(result.len)
