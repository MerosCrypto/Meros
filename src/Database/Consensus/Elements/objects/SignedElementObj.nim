import VerificationObj
import VerificationPacketObj
import SendDifficultyObj
import DataDifficultyObj
import MeritRemovalObj

#Typeclass of every possible signed element type.
type SignedElement* =
  SignedVerification or
  SignedVerificationPacket or
  SignedSendDifficulty or
  SignedDataDifficulty or
  SignedMeritRemoval
