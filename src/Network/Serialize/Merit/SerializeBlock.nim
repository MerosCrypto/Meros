import ../../../lib/Errors

import ../../../Database/Merit/Block

import SerializeBlockHeader, SerializeBlockBody

proc serialize*(
  blockArg: Block,
  capacity: int
): string {.forceCheck: [
  ValueError
].} =
  try:
    result =
      blockArg.header.serialize() &
      blockArg.body.serialize(blockArg.header.sketchSalt, capacity)
  except ValueError as e:
    raise e
