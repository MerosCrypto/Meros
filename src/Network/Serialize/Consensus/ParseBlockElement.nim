import ../../../lib/Errors

import ../../../Database/Consensus/Elements/objects/ElementObj

import ../SerializeCommon
import ParseElement, ParseSendDifficulty, ParseDataDifficulty

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
    result.len = BLOCK_ELEMENT_SET.getLength(data[i]) + 1
  except ValueError as e:
    raise e
  if i + result.len > data.len:
    raise newLoggedException(ValueError, "parseBlockElement not handed enough data to parse the next Element.")

  try:
    case int(data[i]):
      of SEND_DIFFICULTY_PREFIX:
        result.element = parseSendDifficulty(data[i + 1 ..< i + result.len])
      of DATA_DIFFICULTY_PREFIX:
        result.element = parseDataDifficulty(data[i + 1 ..< i + result.len])
      else:
        panic("Possible Element wasn't supported.")
  except ValueError as e:
    raise e
