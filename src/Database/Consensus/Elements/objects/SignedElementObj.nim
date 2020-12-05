import VerificationObj, VerificationPacketObj
import SendDifficultyObj, DataDifficultyObj

#Typeclass of every possible signed element type.
type SignedElement* =
  SignedVerification or
  SignedVerificationPacket or
  SignedSendDifficulty or
  SignedDataDifficulty
