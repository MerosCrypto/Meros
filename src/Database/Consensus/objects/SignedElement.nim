import MeritHolderObj
import SendDifficultyObj
import DataDifficultyObj
import GasPriceObj
import MeritRemovalObj
import VerificationObj

type SignedElement* = SignedSendDifficulty or SignedDataDifficulty or SignedGasPrice or SignedMeritRemoval or SignedVerification
