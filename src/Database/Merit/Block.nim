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

#Verify the sketchCheck merkle.
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
            leaves[h] = Blake384(sketchHashes[h].toBinary().pad(8))

        calculated = newMerkle(leaves).hash

    if calculated != sketchCheck:
        raise newException(ValueError, "Invalid sketchCheck merkle.")

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
        fcRaise e

#Verify the contents merkle.
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
        fcRaise e

    var calculated: Merkle = newMerkle()

    for packet in result:
        calculated.add(Blake384(packet.serializeContents()))
    for elem in elements:
        calculated.add(Blake384(elem.serializeContents()))

    if calculated.hash != contents:
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
