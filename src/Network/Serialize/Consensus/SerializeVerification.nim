import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../Database/Consensus/Elements/objects/VerificationObj

import ../SerializeCommon
import SerializeElement
export SerializeElement

#Serialize a Verification.
method serialize*(
  verif: Verification
): string {.inline, forceCheck: [].} =
  verif.holder.toBinary(NICKNAME_LEN) &
  verif.hash.serialize()

#Serialize a Verification for signing or a MeritRemoval.
method serializeWithoutHolder*(
  verif: Verification
): string {.inline, forceCheck: [].} =
  char(VERIFICATION_PREFIX) &
  verif.hash.serialize()

#Serialize a Verification for inclusion in a BlockHeader's contents Merkle.
#This should never happen.
method serializeContents*(
  verif: Verification
): string {.forceCheck: [].} =
  panic("Verification was serialized for inclusion in a BlockHeader's contents Merkle.")

#Serialize a Signed Verification.
method signedSerialize*(
  verif: SignedVerification
): string {.inline, forceCheck: [].} =
  verif.serialize() &
  verif.signature.serialize()
