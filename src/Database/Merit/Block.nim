#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#MeritHolderRecord object.
import ../common/objects/MeritHolderRecordObj

#Consensus lib.
import ../Consensus/Consensus

#BlockHeader lib.
import BlockHeader

#Block object.
import objects/BlockObj
export BlockObj

#Serialize BlockHeader lib (for inc).
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Serialize Verification lib (for verify).
import ../../Network/Serialize/Consensus/SerializeVerification

#Tables standard lib.
import tables

#Increase the proof.
func inc*(
    blockArg: var Block
) {.forceCheck: [
    ArgonError
].} =
    #Increase the proof.
    inc(blockArg.header.proof)
    #Recalculate the hash.
    try:
        blockArg.header.hash = Argon(blockArg.header.serializeHash(), blockArg.header.proof.toBinary())
    except ArgonError as e:
        fcRaise e

#Verify the aggregate signature for a table of Key -> seq[Hash].
proc verify*(
    blockArg: Block,
    elems: Table[string, seq[Element]]
): bool {.forceCheck: [].} =
    result = true

    #Make sure there's the same amount of MeritHolder as there are records.
    if elems.len != blockArg.records.len:
        return false

    #Aggregate Infos for each MeritHolder.
    var agInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](blockArg.records.len)
    #Iterate over every Record.
    for r, record in blockArg.records:
        #Key in the record.
        var key: string = record.key.toString()

        #Aggregate Infos for this holder.
        var holderAgInfos: seq[BLSAggregationInfo]
        try:
            #Init this MeritHolder's
            holderAgInfos = newSeq[BLSAggregationInfo](elems[key].len)
            #Iterate over this holder's hashes.
            for e, elem in elems[key]:
                #Create AggregationInfos.
                holderAgInfos[e] = newBLSAggregationInfo(record.key, elem.serializeSign())
        #The presented Table has a different set of MeritHolders than the records.
        except KeyError:
            return false
        #Couldn't create an AggregateInfo out of a BLSPublicKey and a hash.
        except BLSError:
            return false

        #Create the aggregate AggregateInfo for this MeritHolder.
        try:
            agInfos[r] = holderAgInfos.aggregate()
        except BLSError:
            return false

    #Calculate the aggregation info.
    var agInfo: BLSAggregationInfo
    try:
        agInfo = agInfos.aggregate()
    except BLSError:
        return false

    #Both the AgInfo and the Aggregate should be null, or neither should be.
    if agInfo.isNil != blockArg.header.aggregate.isNil:
        return false

    #If it's not null, verify it.
    if not agInfo.isNil:
        try:
            blockArg.header.aggregate.setAggregationInfo(agInfo)

            if not blockArg.header.aggregate.verify():
                return false
        except BLSError:
            return false
