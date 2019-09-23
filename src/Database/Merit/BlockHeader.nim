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
func hash*(
    miner: MinerWallet,
    header: var BlockHeader,
    proof: int
) {.forceCheck: [].} =
    header.proof = proof
    header.hash = Argon(
        header.serializeHash(),
        header.proof.toBinary().pad(8)
    )
    header.signature = miner.sign(header.hash.toString())
    header.hash = Argon(header.hash, header.signature.toString())

#Hash the header.
func hash*(
    header: var BlockHeader
) {.forceCheck: [].} =
    header.hash = Argon(
        Argon(
            header.serializeHash(),
            header.proof.toBinary().pad(8)
        ),
        header.signature.toString()
    )

#Constructor.
func newBlockHeader*(
    version: int,
    last: ArgonHash,
    contents: Hash[384],
    verifiers: Hash[384],
    miner: BLSPublicKey,
    time: uint32,
    proof: uint32,
    signature: BLSSignature
): BlockHeader {.forceCheck: [].} =
    result = newBlockHeaderObj(
        version,
        last,
        aggregate,
        miners,
        time,
        proof,
        signature
    )
    result.hash()
