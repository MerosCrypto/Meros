import algorithm

import ../../lib/[Errors, Util, Hash, Merkle, Sketcher]
import ../../Wallet/MinerWallet

import ../Consensus/Elements/Elements

import BlockHeader

import objects/BlockObj
export BlockObj

import ../../Network/Serialize/SerializeCommon

import ../../Network/Serialize/Consensus/[
  SerializeVerification,
  SerializeVerificationPacket,
  SerializeSendDifficulty,
  SerializeDataDifficulty,
  SerializeMeritRemoval
]

proc verifySketchCheck*(
  sketchCheck: Hash[256],
  sketchHashes: seq[uint64]
) {.raises: [
  ValueError
].} =
  var calculated: Hash[256]
  if sketchHashes.len != 0:
    var leaves: seq[Hash[256]] = newSeq[Hash[256]](sketchHashes.len)
    for h in 0 ..< sketchHashes.len:
      if (h != 0) and (sketchHashes[h] == sketchHashes[h - 1]):
        raise newLoggedException(ValueError, "Sketch has a collision.")
      leaves[h] = Blake256(sketchHashes[h].toBinary(SKETCH_HASH_LEN))

    calculated = newMerkle(leaves).hash

  if calculated != sketchCheck:
    raise newLoggedException(ValueError, "Invalid sketchCheck Merkle.")

proc verifySketchCheck*(
  sketchCheck: Hash[256],
  sketchSalt: string,
  packets: seq[VerificationPacket],
  missing: seq[uint64]
) {.raises: [
  ValueError
].} =
  var sketchHashes: seq[uint64] = missing
  for packet in packets:
    sketchHashes.add(sketchHash(sketchSalt, packet))
  sketchHashes.sort(SortOrder.Descending)

  try:
    sketchCheck.verifySketchCheck(sketchHashes)
  except ValueError as e:
    raise e

proc verifyContents*(
  contents: Hash[256],
  packetsArg: seq[VerificationPacket],
  elements: seq[BlockElement]
): seq[VerificationPacket] {.raises: [
  ValueError
].} =
  try:
    result = sorted(
      packetsArg,
      proc (
        x: VerificationPacket,
        y: VerificationPacket
      ): int {.forceCheck: [
        ValueError
      ].} =
        if x.hash > y.hash:
          result = 1
        elif x.hash == y.hash:
          raise newLoggedException(ValueError, "Block has two packets for the same hash.")
        else:
          result = -1
      ,
      SortOrder.Descending
    )
  except ValueError as e:
    raise e

  var
    packetsMerkle: Merkle = newMerkle()
    elementsMerkle: Merkle = newMerkle()
    empty: bool = true

  for packet in result:
    empty = false
    packetsMerkle.add(Blake256(packet.serializeContents()))
  for elem in elements:
    empty = false
    elementsMerkle.add(Blake256(elem.serializeContents()))

  if not empty:
    if Blake256(packetsMerkle.hash.toString() & elementsMerkle.hash.toString()) != contents:
      raise newLoggedException(ValueError, "Invalid contents Merkle.")
  else:
    if contents != Hash[256]():
      raise newLoggedException(ValueError, "Invalid contents Merkle.")

proc verifyAggregate*(
  blockArg: Block,
  lookup: proc (
    holder: uint16
  ): BLSPublicKey {.gcsafe, raises: [
    IndexError
  ].}
): bool {.forceCheck: [].} =
  result = true

  var
    #Aggregation Infos.
    agInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](
      blockArg.body.packets.len + blockArg.body.elements.len
    )
    #Merit Holder Keys. Used as a loop variable for the Verification Packets.
    pubKeys: seq[BLSPublicKey]
  try:
    #Iterate over every Verification Packet.
    for p in 0 ..< blockArg.body.packets.len:
      pubKeys = newSeq[BLSPublicKey](blockArg.body.packets[p].holders.len)
      for h in 0 ..< blockArg.body.packets[p].holders.len:
        pubKeys[h] = lookup(blockArg.body.packets[p].holders[h])

      agInfos[p] = newBLSAggregationInfo(
        pubKeys,
        char(VERIFICATION_PREFIX) & blockArg.body.packets[p].hash.toString()
      )

    #Iterate over every Element.
    for e in 0 ..< blockArg.body.elements.len:
      if blockArg.body.elements[e] of MeritRemoval:
        agInfos[blockArg.body.packets.len + e] = cast[MeritRemoval](blockArg.body.elements[e]).agInfo(lookup(blockArg.body.elements[e].holder))
      else:
        agInfos[blockArg.body.packets.len + e] = newBLSAggregationInfo(
          lookup(blockArg.body.elements[e].holder),
          blockArg.body.elements[e].serializeWithoutHolder()
        )
  #We have Verification Packets/Elements including Verifiers who don't exist.
  except IndexError:
    return false
  #One of our holders has an infinite key.
  except BLSError:
    panic("Holder with an infinite key entered the system.")

  #Verify the Signature.
  try:
    if not blockArg.body.aggregate.verify(agInfos.aggregate()):
      return false
  #We had zero Aggregation Infos. Therefore, the signature should be infinite.
  except BLSError:
    return blockArg.body.aggregate.isInf
