#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#BlockHeader object.
import objects/BlockHeaderObj
export BlockHeaderObj

#Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

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

#Constructor.
func newBlockHeader*(
    version: uint32,
    last: ArgonHash,
    contents: Hash[384],
    verifiers: Hash[384],
    miner: BLSPublicKey,
    time: uint32,
    proof: uint32 = 0,
    signature: BLSSignature = nil
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        contents,
        verifiers,
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
    verifiers: Hash[384],
    miner: int,
    time: uint32,
    proof: uint32 = 0,
    signature: BLSSignature = nil
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        contents,
        verifiers,
        miner,
        time,
        proof,
        signature
    )
    hash(result)
    if signature != nil:
        hash(result)
