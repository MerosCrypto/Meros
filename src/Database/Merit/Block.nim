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

#Element libs.
import ../Consensus/Elements/Elements

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

#Verify the sketchCheck Merkle.
proc verifySketchCheck*(
    sketchCheck: Hash[384],
    sketchHashes: seq[uint64]
) {.raises: [
    ValueError
].} =
    var calculated: Hash[384]
    if sketchHashes.len != 0:
        var leaves: seq[Hash[384]] = newSeq[Hash[384]](sketchHashes.len)
        for h in 0 ..< sketchHashes.len:
            if (h != 0) and (sketchHashes[h] == sketchHashes[h - 1]):
                raise newException(ValueError, "Sketch has a collision.")
            leaves[h] = Blake384(sketchHashes[h].toBinary(SKETCH_HASH_LEN))

        calculated = newMerkle(leaves).hash

    if calculated != sketchCheck:
        raise newException(ValueError, "Invalid sketchCheck Merkle.")

proc verifySketchCheck*(
    sketchCheck: Hash[384],
    sketchSalt: string,
    packets: seq[VerificationPacket],
    missing: seq[uint64]
) {.raises: [
    ValueError
].} =
    var sketchHashes: seq[uint64] = missing
    for packet in packets:
        sketchHashes.add(sketchHash(sketchSalt, packet))
    sketchHashes.sort(SortOrder.Descending)

    try:
        sketchCheck.verifySketchCheck(sketchHashes)
    except ValueError as e:
        raise e

#Verify the contents Merkle.
proc verifyContents*(
    contents: Hash[384],
    packetsArg: seq[VerificationPacket],
    elements: seq[BlockElement]
): seq[VerificationPacket] {.raises: [
    ValueError
].} =
    try:
        result = sorted(
            packetsArg,
            func (
                x: VerificationPacket,
                y: VerificationPacket
            ): int {.forceCheck: [
                ValueError
            ].} =
                if x.hash > y.hash:
                    result = 1
                elif x.hash == y.hash:
                    raise newException(ValueError, "Block has two packets for the same hash.")
                else:
                    result = -1
            , SortOrder.Descending
        )
    except ValueError as e:
        raise e

    var calculated: Merkle = newMerkle()

    for packet in result:
        calculated.add(Blake384(packet.serializeContents()))
    for elem in elements:
        calculated.add(Blake384(elem.serializeContents()))

    if calculated.hash != contents:
        raise newException(ValueError, "Invalid contents Merkle.")

#Verify a Block's aggregate signature via a nickname lookup function and a Table of Hash -> VerificationPacket.
proc verifyAggregate*(
    blockArg: Block,
    lookup: proc (
        holder: uint16
    ): BLSPublicKey {.gcsafe, raises: [
        IndexError
    ].}
): bool {.forceCheck: [].} =
    result = true

    var
        #Aggregation Infos.
        agInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](
            blockArg.body.packets.len + blockArg.body.elements.len
        )
        #Merit Holder Keys. Used as a loop variable for the Verification Packets.
        pubKeys: seq[BLSPublicKey]
    try:
        #Iterate over every Verification Packet.
        for p in 0 ..< blockArg.body.packets.len:
            pubKeys = newSeq[BLSPublicKey](blockArg.body.packets[p].holders.len)
            for h in 0 ..< blockArg.body.packets[p].holders.len:
                pubKeys[h] = lookup(blockArg.body.packets[p].holders[h])

            agInfos[p] = newBLSAggregationInfo(
                pubKeys,
                char(VERIFICATION_PREFIX) & blockArg.body.packets[p].hash.toString()
            )

        #Iterate over every Element.
        for e in 0 ..< blockArg.body.elements.len:
            agInfos[blockArg.body.packets.len + e] = newBLSAggregationInfo(
                lookup(blockArg.body.elements[e].holder),
                blockArg.body.elements[e].serializeWithoutHolder()
            )
    #We have Verification Packets including Verifiers who don't exist.
    except IndexError:
        return false
    #One of our holders has an infinite key.
    except BLSError:
        doAssert(false, "Holder with an infinite key entered the system.")

    #Verify the Signature.
    try:
        if not blockArg.body.aggregate.verify(agInfos.aggregate()):
            return false
    #We had zero Aggregation Infos. Therefore, the signature should be infinite.
    except BLSError:
        return blockArg.body.aggregate.isInf
