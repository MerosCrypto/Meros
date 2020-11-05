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

proc hashForMeritRemovalReason*(
  elem: Element
): Hash[256] {.forceCheck: [].} =
  result = Blake256(elem.serializeWithoutHolder())

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
    e1: Hash[256] = element1.hashForMeritRemovalReason()
    e2: Hash[256] = element2.hashForMeritRemovalReason()

  if e2 < e1:
    var temp: Hash[256] = e2
    e2 = e1
    e1 = temp

  result = Blake256(holder.toBinary(NICKNAME_LEN) & e1.serialize() & e2.serialize())

proc newMeritRemoval*(
  nick: uint16,
  partial: bool,
  e1: Element,
  e2: Element
): MeritRemoval {.forceCheck: [].} =
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
  e1: Element,
  e2: Element,
  signature: BLSSignature
): SignedMeritRemoval {.inline, forceCheck: [].} =
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
    result = newBLSAggregationInfo(holder, mr.element2.serializeWithoutHolder())

    #If this is a partial MeritRemoval, the signature is just the second Element's.
    if mr.partial:
      return

    result = @[
      newBLSAggregationInfo(holder, mr.element1.serializeWithoutHolder()),
      result
    ].aggregate()
  except BLSError:
    panic("Holder with an infinite key entered the system.")
