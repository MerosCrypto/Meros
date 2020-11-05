import ../../../lib/[Errors, Hash, Sketcher]
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/Elements
import ../../../Database/Merit/objects/BlockBodyObj

import ../SerializeCommon

import ../Consensus/[
  SerializeVerification,
  SerializeSendDifficulty,
  SerializeDataDifficulty,
  SerializeMeritRemoval
]

proc serialize*(
  body: BlockBody,
  sketchSalt: string,
  capacityArg: int = 0
): string {.forceCheck: [
  ValueError
].} =
  var capacity: int = capacityArg
  if (capacity == 0) and (body.packets.len != 0):
    capacity = body.packets.len div 5 + 1

  result = body.packetsContents.serialize() & capacity.toBinary(INT_LEN)

  try:
    result &= newSketcher(body.packets).serialize(
      capacity,
      0,
      sketchSalt
    )
  except SaltError as e:
    raise newLoggedException(ValueError, "BlockBody's elements have a collision with the specified sketchSalt: " & e.msg)

  result &= body.elements.len.toBinary(INT_LEN)
  for elem in body.elements:
    if elem of MeritRemoval:
      continue
    result &= elem.serializeContents()

  result &= body.aggregate.serialize()
