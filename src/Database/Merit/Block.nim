#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Element lib.
import ../Consensus/Element

#BlockHeader lib.
import BlockHeader

#Block object.
import objects/BlockObj
export BlockObj

#Serialize BlockHeader lib (for inc).
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Serialize Verification lib.
import ../../Network/Serialize/Consensus/SerializeVerification

#Tables standard lib.
import tables

#Verify a Block's aggregate signature via the State and a Table of Hash -> VerificationPacket.
proc verify*(
    blockArg: Block,
    state: State,
    packets: Table[Hash[384], VerificationPacket]
): bool {.forceCheck: [].} =
    result = true

    #Aggregation Infos.
    var
        agInfos: seq[BLSAggregationInfo] = @[]
        agInfo: AggregationInfo = nil
    try:
        #Iterate over every Transaction.
        for tx in blockArg.transactions:
            for verifier in packets[tx]:
                agInfos.add(newBLSAggregationInfo(state.lookup(verifier), tx.toString()))

        #Iterate over every Element.
        for elem in blockArg.elements:
            agInfos.add(newBLSAggregationInfo(state.lookup(elem.holder), elem.serializeSign()))

        #Aggregate the infos.
        agInfo = agInfos.aggregate()
    #The presented Table is missing VerificationPackets.
    except KeyError:
        doAssert(false, "Called Block.verify() without the needed data.")
    #Couldn't create an AggregationInfo out of a BLSPublicKey and a hash.
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
