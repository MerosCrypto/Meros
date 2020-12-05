import ../../../lib/Errors
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/MeritRemovalObj

import ../SerializeCommon
import SerializeElement

#Serialize a SignedMeritRemoval.
proc serialize*(
  mr: SignedMeritRemoval
): string {.forceCheck: [].} =
  result = mr.holder.toBinary(NICKNAME_LEN)
  if mr.partial:
    result &= "\1"
  else:
    result &= "\0"

  result &=
    mr.element1.serializeWithoutHolder() &
    mr.element2.serializeWithoutHolder() &
    mr.signature.serialize()
