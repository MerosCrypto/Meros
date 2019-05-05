#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#VerifierRecord object.
import ../common/objects/VerifierRecordObj

#Verification lib.
import ../Verifications/Verification

#BlockHeader lib.
import BlockHeader

#Block object.
import objects/BlockObj
export BlockObj

#Serialize BlockHeader libs (for inc).
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Serialize Verification lib (for verify).
import ../../Network/Serialize/Verifications/SerializeVerification

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
        blockArg.header.hash = Argon(blockArg.header.serialize(), blockArg.header.proof.toBinary())
    except ArgonError as e:
        fcRaise e

#Verify the aggregate signature for a table of Key -> seq[Hash].
proc verify*(
    blockArg: Block,
    verifs: Table[string, seq[Verification]]
): bool {.forceCheck: [].} =
    result = true

    #Make sure there's the same amount of Verifier as there are records.
    if verifs.len != blockArg.records.len:
        return false

    #Aggregate Infos for each Verifier.
    var agInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](blockArg.records.len)
    #Iterate over every Record.
    for r, record in blockArg.records:
        #Key in the record.
        var key: string = record.key.toString()

        #Aggregate Infos for this verifier.
        var verifierAgInfos: seq[BLSAggregationInfo]
        try:
            #Init this Verifier's
            verifierAgInfos = newSeq[BLSAggregationInfo](verifs[key].len)
            #Iterate over this verifier's hashes.
            for v, verif in verifs[key]:
                #Create AggregationInfos.
                verifierAgInfos[v] = newBLSAggregationInfo(record.key, verif.serialize(true))
        #The presented Table has a different set of Verifiers than the records.
        except KeyError:
            return false
        #Couldn't create an AggregateInfo out of a BLSPublicKey and a hash.
        except BLSError:
            return false

        #Create the aggregate AggregateInfo for this Verifier.
        try:
            agInfos[r] = verifierAgInfos.aggregate()
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
