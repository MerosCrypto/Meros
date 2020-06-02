#Errors lib.
import ../../../lib/Errors

#Element object.
import ../../../Database/Consensus/Elements/objects/ElementObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse Element libs.
import ParseElement
import ParseSendDifficulty
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
            uint8(VERIFICATION_PACKET_PREFIX)
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
    raise newLoggedException(ValueError, "parseBlockElement not handed enough data to parse the next Element.")

  try:
    case int(data[i]):
      of SEND_DIFFICULTY_PREFIX:
        result.element = parseSendDifficulty(data[i + 1 .. i + result.len])
      of DATA_DIFFICULTY_PREFIX:
        result.element = parseDataDifficulty(data[i + 1 .. i + result.len])
      of GAS_DIFFICULTY_PREFIX:
        panic("GasDifficulties are not supported.")
      of MERIT_REMOVAL_PREFIX:
        result.element = parseMeritRemoval(data[i + 1 .. i + result.len])
      else:
        panic("Possible Element wasn't supported.")
  except ValueError as e:
    raise e

  if int(data[i]) != MERIT_REMOVAL_PREFIX:
    inc(result.len)
