import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import objects/MeritRemovalObj
export MeritRemovalObj

#The serialization of the elements used in the Merit Removal is used to generate a hash.
import ../../../Network/Serialize/SerializeCommon
import ../../../Network/Serialize/Consensus/SerializeVerification

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
    signature
  )

#Calculate the MeritRemoval's aggregation info.
proc agInfo*(
  mr: SignedMeritRemoval,
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
