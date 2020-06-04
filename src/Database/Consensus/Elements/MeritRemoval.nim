import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import VerificationPacket as VerificationPacketFile

import objects/MeritRemovalObj
export MeritRemovalObj

#The serialization of the elements used in the Merit Removal is used to generate a hash.
import ../../../Network/Serialize/SerializeCommon
import ../../../Network/Serialize/Consensus/[
  SerializeVerification,
  SerializeVerificationPacket,
  SerializeMeritRemoval
]

#Calculate a hash representing the reason for a MeritRemoval.
#By making sure every Merit Removal
# - No matter what the sub-element is packeted with.
# - No matter the order of the sub-elements.
#has an unique hash, we prevent Merit Removals being spammed for the same person, each 'valid'.
proc calculateMeritRemovalReason*(
  holder: uint16,
  element1: Element,
  element2: Element
): Hash[256] {.forceCheck: [].} =
  var
    e1: Hash[256]
    e2: Hash[256]

  if element1 of MeritRemovalVerificationPacket:
    e1 = Blake256(
      cast[MeritRemovalVerificationPacket](element1).serializeAsVerificationWithoutHolder()
    )
  else:
    e1 = Blake256(element1.serializeWithoutHolder())

  if element2 of MeritRemovalVerificationPacket:
    e2 = Blake256(
      cast[MeritRemovalVerificationPacket](element2).serializeAsVerificationWithoutHolder()
    )
  else:
    e2 = Blake256(element2.serializeWithoutHolder())

  if e2 < e1:
    var temp: Hash[256] = e2
    e2 = e1
    e1 = temp

  result = Blake256(holder.toBinary(NICKNAME_LEN) & e1.serialize() & e2.serialize())

proc newMeritRemoval*(
  nick: uint16,
  partial: bool,
  e1Arg: Element,
  e2Arg: Element,
  lookup: seq[BLSPublicKey]
): MeritRemoval {.forceCheck: [].} =
  var
    e1: Element = e1Arg
    e2: Element = e2Arg
  if e1 of VerificationPacket:
    e1 = cast[VerificationPacket](e1).toMeritRemovalVerificationPacket(lookup)
  if e2 of VerificationPacket:
    e2 = cast[VerificationPacket](e2).toMeritRemovalVerificationPacket(lookup)

  result = newMeritRemovalObj(
    nick,
    partial,
    e1,
    e2,
    calculateMeritRemovalReason(nick, e1, e2)
  )

proc newSignedMeritRemoval*(
  nick: uint16,
  partial: bool,
  e1Arg: Element,
  e2Arg: Element,
  signature: BLSSignature,
  lookup: seq[BLSPublicKey]
): SignedMeritRemoval {.inline, forceCheck: [].} =
  var
    e1: Element = e1Arg
    e2: Element = e2Arg
  if e1 of VerificationPacket:
    e1 = cast[VerificationPacket](e1).toMeritRemovalVerificationPacket(lookup)
  if e2 of VerificationPacket:
    e2 = cast[VerificationPacket](e2).toMeritRemovalVerificationPacket(lookup)

  newSignedMeritRemovalObj(
    nick,
    partial,
    e1,
    e2,
    calculateMeritRemovalReason(nick, e1, e2),
    signature
  )

#Calculate the MeritRemoval's Merkle leaf hash (used for inclusion in a Block).
proc merkle*(
  mr: MeritRemoval
): Hash[256] {.forceCheck: [].} =
  Blake256(char(MERIT_REMOVAL_PREFIX) & mr.serialize())

#Calculate the MeritRemoval's aggregation info.
proc agInfo*(
  mr: MeritRemoval,
  holder: BLSPublicKey
): BLSAggregationInfo {.forceCheck: [].} =
  try:
    if mr.element2 of MeritRemovalVerificationPacket:
      var packet: MeritRemovalVerificationPacket = cast[MeritRemovalVerificationPacket](mr.element2)
      result = newBLSAggregationInfo(packet.holders.aggregate(), packet.serializeAsVerificationWithoutHolder())
    else:
      result = newBLSAggregationInfo(holder, mr.element2.serializeWithoutHolder())

    #If this is a partial MeritRemoval, the signature is just the second Element's.
    if mr.partial:
      return

    if mr.element1 of MeritRemovalVerificationPacket:
      var packet: MeritRemovalVerificationPacket = cast[MeritRemovalVerificationPacket](mr.element1)
      result = @[
        newBLSAggregationInfo(packet.holders.aggregate(), packet.serializeAsVerificationWithoutHolder()),
        result
      ].aggregate()
    else:
      result = @[
        newBLSAggregationInfo(holder, mr.element1.serializeWithoutHolder()),
        result
      ].aggregate()
  except BLSError:
    panic("Holder with an infinite key entered the system.")
