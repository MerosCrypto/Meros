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

#ConsensusIndex and MeritHolderRecord objects.
import ../common/objects/ConsensusIndexObj
import ../common/objects/MeritHolderRecordObj
export ConsensusIndex

#Signed Element object.
import objects/SignedElementObj
export SignedElementObj

#Element and MeritHolder libs.
import Element
import MeritHolder
export Element
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

#Handle unknown Verifications.
proc handleUnknown*(
    consensus: Consensus,
    verif: Verification,
    txExists: bool
) {.forceCheck: [].} =
    if txExists:
        return

    var hash: string = verif.hash.toString()
    if not consensus.unknowns.hasKey(hash):
        consensus.unknowns[hash] = newSeq[seq[BLSPublicKey]](6)

    try:
        consensus.unknowns[hash][5].add(verif.holder)
    except KeyError as e:
        doAssert(false, "Couldn't add a Merit Holder to a seq we've confirmed to exist: " & e.msg)

    consensus.db.saveUnknown(verif)

#Add a Verification.
proc add*(
    consensus: Consensus,
    verif: Verification,
    txExists: bool
) {.forceCheck: [
    GapError,
    DataExists,
    MaliciousMeritHolder
].} =
    try:
        consensus[verif.holder].add(verif)
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        fcRaise e

    consensus.handleUnknown(verif, txExists)

#Add a SignedVerification.
proc add*(
    consensus: Consensus,
    verif: SignedVerification,
    txExists: bool
) {.forceCheck: [
    ValueError,
    GapError,
    BLSError,
    DataExists,
    MaliciousMeritHolder
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
    except MaliciousMeritHolder as e:
        fcRaise e

    consensus.handleUnknown(verif, txExists)

#For each provided Record, archive all Elements from the account's last archived to the provided nonce.
proc archive*(
    consensus: Consensus,
    records: seq[MeritHolderRecord]
) {.forceCheck: [].} =
    #Iterate over every Record.
    for record in records:
        #Make sure this MeritHolder has Elements to archive.
        if consensus[record.key].archived == consensus[record.key].height - 1:
            doAssert(false, "Tried to archive Elements from a MeritHolder without any pending Elements.")

        #Make sure this MeritHolder has enough Elements.
        if record.nonce >= consensus[record.key].height:
            doAssert(false, "Tried to archive more Elements than this MeritHolder has pending.")

        #Delete the old signatures.
        for e in consensus[record.key].archived + 1 ..< consensus[record.key].height:
            consensus[record.key].signatures.del(e)

        #Reset the Merkle.
        var elem: Element
        consensus[record.key].merkle = newMerkle()
        for e in record.nonce + 1 ..< consensus[record.key].height:
            try:
                elem = consensus[record.key][e]
            except IndexError as e:
                doAssert(false, "Couldn't get an element we know we have: " & e.msg)

            case elem:
                of Verification as verif:
                    consensus[record.key].merkle.add(verif.hash)
                else:
                    doAssert(false, "Element should be a Verification.")

        #Update the archived field.
        consensus[record.key].archived = record.nonce

        #Update the DB.
        consensus.db.save(record.key, record.nonce)

    #Shift over the Verifications for unknown hashes.
    var toDelete: seq[string] = @[]
    for key in consensus.unknowns.keys():
        try:
            consensus.unknowns[key].add(@[])
            consensus.unknowns[key].delete(0)

            for i in 0 ..< 5:
                if consensus.unknowns[key][i].len != 0:
                    break

                if i == 4:
                    toDelete.add(key)
        except KeyError as e:
            doAssert(false, "Couldn't access a value with an a key we got with .keys(): " & e.msg)
    for key in toDelete:
        consensus.unknowns.del(key)

    consensus.db.advanceUnknown()
