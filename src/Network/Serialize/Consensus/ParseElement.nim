import ../../../lib/Errors

import ../SerializeCommon

#Get the length of the upcoming Block/MeritRemoval Element.
proc getLength*(
  possibilities: set[byte],
  prefix: char,
  holders: int = 0,
  actual: int = -1
): int {.forceCheck: [
  ValueError
].} =
  if not (byte(prefix) in possibilities):
    raise newLoggedException(ValueError, "Parsing an Element that isn't a valid Element for this data.")

  case int(prefix):
    #Verifications are never in Blocks. Verifications in MeritRemovals don't have their holder.
    of VERIFICATION_PREFIX:
      result = HASH_LEN

    of SEND_DIFFICULTY_PREFIX:
      result = NICKNAME_LEN + INT_LEN + INT_LEN
      if actual == MERIT_REMOVAL_PREFIX:
        result -= NICKNAME_LEN

    of DATA_DIFFICULTY_PREFIX:
      result = NICKNAME_LEN + INT_LEN + INT_LEN
      if actual == MERIT_REMOVAL_PREFIX:
        result -= NICKNAME_LEN

    else:
      panic("Possible Element wasn't supported.")

  if actual == MERIT_REMOVAL_PREFIX:
    inc(result)
