#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Sketcher lib.
import ../../../lib/Sketcher

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element libs.
import ../../../Database/Consensus/Elements/Elements

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Serialize Element libs.
import ../Consensus/SerializeVerification
import ../Consensus/SerializeSendDifficulty
import ../Consensus/SerializeDataDifficulty
import ../Consensus/SerializeMeritRemoval

#Serialize a Block.
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
    result &= elem.serializeContents()

  result &= body.aggregate.serialize()
