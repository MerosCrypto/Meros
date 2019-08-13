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

#Flag a MeritHolder as malicious.
proc flag*(
    consensus: Consensus,
    removal: MeritRemoval
) {.forceCheck: [].} =
    if consensus.malicious.hasKey(removal.holder.toString()):
        return
    consensus.malicious[removal.holder.toString()] = removal

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
    GapError
].} =
    try:
        consensus[verif.holder].add(verif)
    except GapError as e:
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
    DataExists,
    MaliciousMeritHolder
].} =
    try:
        consensus[verif.holder].add(verif)
    except ValueError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        #Manually recreate the Exception since fcRaise wouldn't include the MeritRemoval.
        raise newMaliciousMeritHolder(
            e.msg,
            e.removal
        )

    consensus.handleUnknown(verif, txExists)

#Add a MeritRemoval.
proc add*(
    consensus: Consensus,
    mr: MeritRemoval
) {.forceCheck: [
    ValueError
].} =
    #If this is a partial MeritRemoval, make sure the first Element is already archived on this Consensus DAG.
    if mr.partial:
        if mr.element1.nonce < consensus[mr.holder].archived:
            raise newException(ValueError, "Partial MeritRemoval references unarchived Element.")

        try:
            if mr.element1 != consensus[mr.holder][mr.element1.nonce]:
                raise newException(ValueError, "Partial MeritRemoval references Element not on this chain.")
        except IndexError as e:
            doAssert(false, "Failed to load an archived Element: " & e.msg)

    #Same nonce.
    if mr.element1.nonce == mr.element2.nonce:
        if mr.element1 == mr.element2:
            raise newException(ValueError, "Same Nonce MeritRemoval uses the same Elements.")
    #Verified competing elements.
    else:
        doAssert(false, "Verified competing MeritRemovals aren't supported.")

    consensus.flag(mr)

#Archive a MeritRemoval. This:
#- Sets the MeritHolder's height to 1 above the archived height.
#- Saves the element to its position.
proc archive*(
    consensus: Consensus,
    mr: MeritRemoval,
    nonce: int
) {.forceCheck: [].} =
    #Set the MeritRemoval's nonce.
    try:
        mr.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when archicing a MeritRemoval: " & e.msg)

    #Grab the MeritHolder.
    var mh: MeritHolder
    try:
        mh = consensus[mr.holder]
    except KeyError as e:
        doAssert(false, "Couldn't get the MeritHolder who caused a valid MeritRemoval: " & e.msg)

    #Delete reverted elements (except the first which we overwrite).
    for e in mh.archived + 2 ..< mh.height:
        consensus.db.del(mr.holder, e)

    #Correct the height.
    mh.height = mh.archived + 2

    #Save the element.
    consensus.db.save(mr)

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
                consensus[record.key].addToMerkle(consensus[record.key][e])
            except IndexError as e:
                doAssert(false, "Couldn't get an element we know we have: " & e.msg)

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
