#Element objects.
import VerificationObj
import SendDifficultyObj
import DataDifficultyObj
import GasPriceObj
import MeritRemovalObj

#SignedElement typeclass.
type SignedElement* =
    SignedVerification or
    SignedSendDifficulty or
    SignedDataDifficulty or
    SignedGasPrice or
    SignedMeritRemoval
