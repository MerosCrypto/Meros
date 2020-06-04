import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/MeritRemovalObj

import ../SerializeCommon
import SerializeElement, SerializeVerification
export SerializeElement

#Serialize a MeritRemoval.
method serialize*(
  mr: MeritRemoval
): string {.forceCheck: [].} =
  result = mr.holder.toBinary(NICKNAME_LEN)

  if mr.partial:
    result &= "\1"
  else:
    result &= "\0"

  result &=
    mr.element1.serializeWithoutHolder() &
    mr.element2.serializeWithoutHolder()

#Serialize a MeritRemoval for inclusion in a BlockHeader's contents Merkle.
method serializeContents*(
  mr: MeritRemoval
): string {.inline, forceCheck: [].} =
  char(MERIT_REMOVAL_PREFIX) &
  mr.serialize()

#Serialize a Signed MeritRemoval.
method signedSerialize*(
  mr: SignedMeritRemoval
): string {.inline, forceCheck: [].} =
  mr.serialize() &
  mr.signature.serialize()
