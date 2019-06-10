#Errors.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Consensus DB lib.
import ../Filesystem/DB/ConsensusDB

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
    db: DB
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
        #Make sure this MeritHolder has Elements to archive.
        if consensus[record.key].elements.len == 0:
            doAssert(false, "Tried to archive Elements from a MeritHolder without any pending Elements.")

        #Make sure this MeritHolder has enough Elements.
        if (record.nonce - consensus[record.key].elements[0].nonce) + 1 < consensus[record.key].elements.len:
            doAssert(false, "Tried to archive more Elements than this MeritHolder has pending.")

        #Delete them from the seq.
        consensus[record.key].elements.delete(
            0,
            record.nonce - consensus[record.key].elements[0].nonce
        )

        #Reset the Merkle.
        consensus[record.key].merkle = newMerkle()
        for verif in consensus[record.key].elements:
            consensus[record.key].merkle.add(verif.hash)

        #Update the archived field.
        consensus[record.key].archived = record.nonce

        #Update the DB.
        try:
            consensus.db.save(record.key, record.nonce)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a MeritHolder's tip to the Database: " & e.msg)
