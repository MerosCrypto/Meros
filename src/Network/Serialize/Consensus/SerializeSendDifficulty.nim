#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#SendDifficulty object.
import ../../../Database/Consensus/Elements/objects/SendDifficultyObj

#Common serialization functions.
import ../SerializeCommon

#SerializeElement method.
import SerializeElement
export SerializeElement

#Serialize a SendDifficulty.
method serialize*(
  sendDiff: SendDifficulty
): string {.inline, forceCheck: [].} =
  sendDiff.holder.toBinary(NICKNAME_LEN) &
  sendDiff.nonce.toBinary(INT_LEN) &
  sendDiff.difficulty.toBinary(INT_LEN)

#Serialize a SendDifficulty for signing or a MeritRemoval.
method serializeWithoutHolder*(
  sendDiff: SendDifficulty
): string {.inline, forceCheck: [].} =
  char(SEND_DIFFICULTY_PREFIX) &
  sendDiff.nonce.toBinary(INT_LEN) &
  sendDiff.difficulty.toBinary(INT_LEN)

#Serialize a SendDifficulty for inclusion in a BlockHeader's contents Merkle.
method serializeContents*(
  sendDiff: SendDifficulty
): string {.inline, forceCheck: [].} =
  char(SEND_DIFFICULTY_PREFIX) &
  sendDiff.serialize()

#Serialize a Signed SendDifficulty.
method signedSerialize*(
  sendDiff: SignedSendDifficulty
): string {.inline, forceCheck: [].} =
  sendDiff.serialize() &
  sendDiff.signature.serialize()
