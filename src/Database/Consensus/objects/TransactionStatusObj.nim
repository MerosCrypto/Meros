#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification Packet object.
import ../Elements/objects/VerificationPacketObj

#Finals lib.
import finals

#Tables standard lib.
import tables

#Transaction Status.
type TransactionStatus* = ref object
    #Block number that the Transaction's Epoch ends in.
    epoch*: int

    #Whether or not the Transaction has competitors.
    #If it does, Meros will only mark the Transaction as verified at the end of its Epoch.
    #False means the Transaction has no competitors and just has to cross the threshold.
    #True means the Transaction has competitors and will not be verified until its Epoch ends.
    competing*: bool

    #If the Transaction was verified.
    #If the Transaction was already verified, and then a competing Transaction is found, both competing and verified will be true.
    verified*: bool

    #If the Transaction was beaten when finalized.
    #If the Transaction's parent was beaten, this Transaction is automatically beaten.
    beaten*: bool

    #List of VerificationPackets.
    packets*: seq[VerificationPacket]
    #Packet for the next Block.
    pending*: SignedVerificationPacket
    #Table of holder to their signature.
    signatures*: Table[uint16, BLSSignature]

    #The final Merit tally. -1 if the Transaction is still in Epochs.
    merit*: int

#Constructor.
proc newTransactionStatusObj*(
    hash: Hash[384],
    epoch: int
): TransactionStatus {.inline, forceCheck: [].} =
    TransactionStatus(
        epoch: epoch,
        competing: false,
        verified: false,
        beaten: false,
        packets: @[],
        pending: newSignedVerificationPacketObj(hash),
        signatures: initTable[uint16, BLSSignature](),
        merit: -1
    )
