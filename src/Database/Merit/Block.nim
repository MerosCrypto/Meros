#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash and Merkle libs.
import ../../lib/Hash
import ../../lib/Merkle

#Sketcher lib.
import ../../lib/Sketcher

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Element lib.
import ../Consensus/Elements/Element

#BlockHeader lib.
import BlockHeader

#Block object.
import objects/BlockObj
export BlockObj

#SerializeCommon lib.
import ../../Network/Serialize/SerializeCommon

#Serialize Element libs.
import ../../Network/Serialize/Consensus/SerializeElement

#Algorithm standard lib.
import algorithm

#Tables standard lib.
import tables

#Verify the contents merkle.
proc verifyContents*(
    contents: Hash[384],
    sketchSalt: string,
    packets: seq[VerificationPacket],
    missing: seq[uint64],
    elements: seq[BlockElement]
) {.raises: [
    ValueError
].} =
    var calculated: Hash[384]
    if ((packets.len + missing.len) != 0) or (elements.len != 0):
        var
            sketchHashes: seq[uint64] = missing
            packetsSide: Merkle = newMerkle()

            elementsSide: Merkle = newMerkle()

        for packet in packets:
            sketchHashes.add(sketchHash(sketchSalt, packet))
        sketchHashes.sort(SortOrder.Descending)

        for hash in sketchHashes:
            packetsSide.add(Blake384(hash.toBinary().pad(8)))

        for elem in elements:
            elementsSide.add(Blake384(elem.serializeContents()))

        calculated = Blake384(packetsSide.hash.toString() & elementsSide.hash.toString())

    if calculated != contents:
        raise newException(ValueError, "Invalid contents merkle.")

#Verify a Block's aggregate signature via a nickname lookup function and a Table of Hash -> VerificationPacket.
proc verifyAggregate*(
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
