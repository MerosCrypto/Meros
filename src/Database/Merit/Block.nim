#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Element lib and VerificationPacket object.
import ../Consensus/Elements/Element
import ../Consensus/Elements/objects/VerificationPacketObj

#BlockHeader lib.
import BlockHeader

#Block object.
import objects/BlockObj
export BlockObj

#SerializeCommon lib.
import ../../Network/Serialize/SerializeCommon

#Serialize Element libs.
import ../../Network/Serialize/Consensus/SerializeElement

#Tables standard lib.
import tables

#Verify a Block's aggregate signature via a nickname lookup function and a Table of Hash -> VerificationPacket.
proc verify*(
    blockArg: Block,
    lookup: proc (
        holder: uint16
    ): BLSPublicKey {.raises: [
        IndexError
    ].}
): bool {.forceCheck: [].} =
    result = true

    #Aggregation Infos.
    var
        agInfos: seq[BLSAggregationInfo] = @[]
        agInfo: BLSAggregationInfo = nil
    try:
        #Iterate over every Verification Packet.
        for packet in blockArg.body.packets:
            for verifier in packet.holders:
                agInfos.add(newBLSAggregationInfo(
                    lookup(verifier),
                    char(VERIFICATION_PREFIX) & packet.hash.toString()
                ))

        #Iterate over every Element.
        for elem in blockArg.body.elements:
            agInfos.add(newBLSAggregationInfo(lookup(elem.holder), elem.serializeWithoutHolder()))

        #Aggregate the infos.
        agInfo = agInfos.aggregate()
    #We have VerificationPackets including Verifiers who don't exist.
    except IndexError:
        return false
    #Couldn't create an AggregationInfo out of a BLSPublicKey and a hash.
    except BLSError:
        return false

    #Both the AgInfo and the Aggregate should be null, or neither should be.
    if agInfo.isNil != blockArg.body.aggregate.isNil:
        return false

    #If it's not null, verify it.
    if not agInfo.isNil:
        try:
            blockArg.body.aggregate.setAggregationInfo(agInfo)
            if not blockArg.body.aggregate.verify():
                return false
        except BLSError:
            return false
