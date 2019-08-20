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

#Serialize Verification lib.
import ../../Network/Serialize/Consensus/SerializeVerification

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
    #Make sure there's a seq.
    if not consensus.malicious.hasKey(removal.holder.toString()):
        consensus.malicious[removal.holder.toString()] = @[]

    #Add the MeritRemoval.
    try:
        consensus.malicious[removal.holder.toString()].add(removal)
    except KeyError as e:
        doAssert(false, "Couldn't add a MeritRemoval to a seq we've confirmed exists: " & e.msg)

proc checkMalicious*(
    consensus: Consensus,
    verif: SignedVerification
) {.forceCheck: [
    GapError,
    DataExists,
    MaliciousMeritHolder
].} =
    #This method is called before the Element is added.
    #Only when we add the Element, do we verify its signature.
    #This method will fail to aggregate unless we set its AggregationInfo now.
    try:
        verif.signature.setAggregationInfo(
            newBLSAggregationInfo(
                verif.holder,
                verif.serializeSign()
            )
        )
    except BLSError as e:
        doAssert(false, "Failed to create a BLS Aggregation Info: " & e.msg)

    try:
        consensus[verif.holder].checkMalicious(verif)
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

#Handle unknown Verifications.
proc handleUnknown(
    consensus: Consensus,
    verif: Verification,
    txExists: bool
) {.forceCheck: [].} =
    if txExists:
        return

    var hash: string = verif.hash.toString()
    if not consensus.unknowns.hasKey(hash):
        consensus.unknowns[hash] = newSeq[BLSPublicKey]()

    try:
        consensus.unknowns[hash].add(verif.holder)
    except KeyError as e:
        doAssert(false, "Couldn't add a Merit Holder to a seq we've confirmed to exist: " & e.msg)

#Add a Verification.
proc add*(
    consensus: Consensus,
    verif: Verification,
    txExists: bool
) {.forceCheck: [
    ValueError,
    GapError,
    DataExists
].} =
    try:
        consensus[verif.holder].add(verif)
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MaliciousMeritHolder as e:
        raise newException(ValueError, "Tried to add an Element from a Block which would cause a MeritRemoval: " & e.msg)

    consensus.handleUnknown(verif, txExists)

#Add a SignedVerification.
proc add*(
    consensus: Consensus,
    verif: SignedVerification
) {.forceCheck: [
    ValueError,
    GapError
].} =
    try:
        consensus[verif.holder].add(verif)
    except ValueError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except DataExists as e:
        doAssert(false, "Tried to add a SignedVerification which caused was already added. This should've been checked via checkMalicious before hand: " & e.msg)
    except MaliciousMeritHolder as e:
        doAssert(false, "Tried to add a SignedVerification which caused a MeritRemoval. This should've been checked via checkMalicious before hand: " & e.msg)

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

#Add a SignedMeritRemoval.
proc add*(
    consensus: Consensus,
    mr: SignedMeritRemoval
) {.forceCheck: [
    ValueError
].} =
    #Verify the MeritRemoval's signature.
    try:
        mr.signature.setAggregationInfo(mr.agInfo)
        if not mr.signature.verify():
            raise newException(ValueError, "Invalid MeritRemoval signature.")
    except BLSError as e:
        doAssert(false, "Failed to verify the MeritRemoval's signature: " & e.msg)

    #Add the MeritRemoval.
    try:
        consensus.add(cast[MeritRemoval](mr))
    except ValueError as e:
        fcRaise e

#Archive a MeritRemoval. This:
#- Sets the MeritHolder's height to 1 above the archived height.
#- Saves the element to its position.
proc archive*(
    consensus: Consensus,
    mr: MeritRemoval
) {.forceCheck: [].} =
    #Grab the MeritHolder.
    var mh: MeritHolder
    try:
        mh = consensus[mr.holder]
    except KeyError as e:
        doAssert(false, "Couldn't get the MeritHolder who caused a valid MeritRemoval: " & e.msg)

    #Set the MeritRemoval's nonce.
    try:
        mr.nonce = mh.archived + 1
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when archicing a MeritRemoval: " & e.msg)

    #Delete reverted elements (except the first which we overwrite).
    for e in mh.archived + 2 ..< mh.height:
        consensus.db.del(mr.holder, e)

    #Correct the height.
    mh.height = mh.archived + 2

    #Save the element.
    consensus.db.save(mr)

    #Delete the MeritRemovals from the malicious table.
    consensus.malicious.del(mr.holder.toString())

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
