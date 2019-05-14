#Errors.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Merkle lib.
import ../common/Merkle

#ConsensusIndex and MeritHolderRecord object.
import ../common/objects/ConsensusIndexObj
import ../common/objects/MeritHolderRecordObj
export ConsensusIndex

#Verification and MeritHolder libs.
import Verification
import MeritHolder
export Verification
export MeritHolder

#Consensus object.
import objects/ConsensusObj
export ConsensusObj

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Constructor wrapper.
proc newConsensus*(
    db: DatabaseFunctionBox
): Consensus {.forceCheck: [].} =
    newConsensusObj(db)

#Add a Verification.
proc add*(
    consensus: Consensus,
    verif: Verification
) {.forceCheck: [
    GapError,
    DataExists,
    MeritRemoval
].} =
    try:
        consensus[verif.holder].add(verif)
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MeritRemoval as e:
        fcRaise e

#Add a SignedVerification.
proc add*(
    consensus: Consensus,
    verif: SignedVerification
) {.forceCheck: [
    ValueError,
    GapError,
    BLSError,
    DataExists,
    MeritRemoval
].} =
    try:
        consensus[verif.holder].add(verif)
    except ValueError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MeritRemoval as e:
        fcRaise e

#For each provided Record, archive all Elements from the account's last archived to the provided nonce.
proc archive*(
    consensus: Consensus,
    records: seq[MeritHolderRecord]
) {.forceCheck: [].} =
    #Iterate over every Record.
    for record in records:
        #Delete them from the seq.
        try:
            consensus[record.key].elements.delete(
                0,
                record.nonce - consensus[record.key].elements[0].nonce
            )
        except IndexError as e:
            doAssert(false, "Tried to archive Elements from a MeritHolder without any pending Elements: " & e.msg)

        #Reset the Merkle.
        consensus[record.key].merkle = newMerkle()
        for verif in consensus[record.key].elements:
            consensus[record.key].merkle.add(verif.hash)

        #Update the archived field.
        consensus[record.key].archived = record.nonce

        #Update the DB.
        try:
            consensus.db.put("consensus_" & record.key.toString(), $record.nonce)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a MeritHolder's tip to the Database: " & e.msg)
