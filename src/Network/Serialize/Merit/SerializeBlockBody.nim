import ../../../lib/[Errors, Hash, Sketcher]
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/Elements
import ../../../Database/Merit/objects/BlockBodyObj

import ../SerializeCommon

import ../Consensus/SerializeElement

proc serialize*(
  body: BlockBody,
  sketchSalt: string,
  capacityArg: int
): string {.forceCheck: [
  ValueError
].} =
  var capacity: int = min(max(capacityArg, 0), body.packets.len)

  result = body.packetsContents.serialize() & capacity.toBinary(INT_LEN)
  try:
    result &= body.packets.serialize(capacity, sketchSalt)
  except SaltError as e:
    raise newLoggedException(ValueError, "BlockBody's elements have a collision with the specified sketchSalt: " & e.msg)

  result &= body.elements.len.toBinary(INT_LEN)
  for elem in body.elements:
    result &= elem.serializeContents()

  result &= body.aggregate.serialize()
