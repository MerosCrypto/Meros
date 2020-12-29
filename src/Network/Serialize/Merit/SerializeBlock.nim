import ../../../lib/Errors

import ../../../Database/Merit/Block

import SerializeBlockHeader, SerializeBlockBody

proc serialize*(
  blockArg: Block
): string {.forceCheck: [
  ValueError
].} =
  try:
    result =
      blockArg.header.serialize(blockArg.body.packets.len) &
      blockArg.body.serialize(blockArg.header.sketchSalt)
  except ValueError as e:
    raise e
