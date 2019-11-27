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

#BlockHeader object.
import objects/BlockHeaderObj
export BlockHeaderObj

#SerializeCommon lib.
import ../../Network/Serialize/SerializeCommon

#Element Serialization libs.
import ../../Network/Serialize/Consensus/SerializeVerification
import ../../Network/Serialize/Consensus/SerializeVerificationPacket
import ../../Network/Serialize/Consensus/SerializeMeritRemoval

#BlockHeader Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Algorithm standard lib.
import algorithm

#Sign and hash the header.
proc hash*(
    miner: MinerWallet,
    header: var BlockHeader,
    proof: uint32
) {.forceCheck: [
    BLSError
].} =
    header.proof = proof
    try:
        miner.hash(header, header.serializeHash(), proof)
    except BLSError as e:
        fcRaise e

#Hash the header.
func hash*(
    header: var BlockHeader
) {.forceCheck: [].} =
    #header.hash would be preferred yet it failed to compile. Likely due to the hash field.
    hash(
        header,
        header.serializeHash()
    )

#Create a sketchCheck Merkle.
proc newSketchCheck*(
    sketchSalt: string,
    packets: seq[VerificationPacket]
): Hash[384] {.forceCheck: [].} =
    var
        sketchHashes: seq[uint64] = @[]
        calculated: Merkle = newMerkle()

    for packet in packets:
        sketchHashes.add(sketchHash(sketchSalt, packet))
    sketchHashes.sort(SortOrder.Descending)

    for hash in sketchHashes:
        calculated.add(Blake384(hash.toBinary(SKETCH_HASH_LEN)))

    result = calculated.hash

#Create a contents Merkle.
proc newContents*(
    packets: seq[VerificationPacket],
    elements: seq[BlockElement]
): Hash[384] {.forceCheck: [].} =
    var calculated: Merkle = newMerkle()

    for packet in sorted(
        packets,
        func (
            x: VerificationPacket,
            y: VerificationPacket
        ): int {.forceCheck: [].} =
            if x.hash > y.hash:
                result = 1
            else:
                result = -1
        , SortOrder.Descending
    ):
        calculated.add(Blake384(packet.serializeContents()))

    for elem in elements:
        calculated.add(Blake384(elem.serializeContents()))

    result = calculated.hash

#Constructor.
func newBlockHeader*(
    version: uint32,
    last: ArgonHash,
    contents: Hash[384],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[384],
    miner: BLSPublicKey,
    time: uint32,
    proof: uint32 = 0,
    signature: BLSSignature = nil
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        contents,
        significant,
        sketchSalt,
        sketchCheck,
        miner,
        time,
        proof,
        signature
    )
    if signature != nil:
        hash(result)

func newBlockHeader*(
    version: uint32,
    last: ArgonHash,
    contents: Hash[384],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[384],
    miner: uint16,
    time: uint32,
    proof: uint32 = 0,
    signature: BLSSignature = nil
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        contents,
        significant,
        sketchSalt,
        sketchCheck,
        miner,
        time,
        proof,
        signature
    )
    hash(result)
    if signature != nil:
        hash(result)
