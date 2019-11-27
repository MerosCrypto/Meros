#Element objects.
import VerificationObj
import VerificationPacketObj
import SendDifficultyObj
import DataDifficultyObj
import GasPriceObj
import MeritRemovalObj

#SignedElement typeclass.
type SignedElement* =
    SignedVerification or
    SignedVerificationPacket or
    SignedSendDifficulty or
    SignedDataDifficulty or
    SignedGasPrice or
    SignedMeritRemoval
