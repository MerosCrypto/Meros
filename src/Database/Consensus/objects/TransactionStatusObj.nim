#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

#Transaction Status.
type TransactionStatus* = ref object
    #Block number that the Transaction's Epoch ends in.
    epoch*: int
    #Whether or not the Transaction can only be verified at the end of the Transaction's Epoch.
    #False means the Transaction just has to cross the threshold.
    #True means the Transaction cannot be verified until its Epoch ends.
    #This is not technically defaulting, as the Transaction may have more than the threshold of Merit, yet it looks similar.
    #It's used when the Transaction has a competitor.
    defaulting*: bool
    #List of Verifiers.
    verifiers*: seq[BLSPublicKey]
    #If the Transaction was verified.
    #If the Transaction was already verified, and then a competing Transaction is found, both defaulting and verified will be true.
    verified*: bool

#Constructor.
proc newTransactionStatusObj*(
    epoch: int
): TransactionStatus {.inline, forceCheck: [].} =
    TransactionStatus(
        epoch: epoch,
        defaulting: false,
        verifiers: @[],
        verified: false
    )
