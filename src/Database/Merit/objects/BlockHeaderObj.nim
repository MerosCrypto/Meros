#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Finals lib.
import finals

finalsd:
    type BlockHeader* = object
        #Version.
        version {.final.}: int
        #Hash of the last block.
        last* {.final.}: ArgonHash

        #Merkle of the contents.
        contents: Hash[384]
        #Merkle of who verified each Transaction.
        verifiers: Hash[384]

        #Miner.
        miner {.final.}: BLSPublicKey
        #Timestamp.
        time*: uint32
        #Proof.
        proof*: uint32
        #Signature.
        signature: BLSSignature

        #Block hash.
        hash*: ArgonHash

#Constructor.
func newBlockHeaderObj*(
    version: int,
    last: ArgonHash,
    contents: Hash[384],
    verifiers: Hash[384],
    miner: BLSPublicKey,
    time: uint32,
    proof: uint32,
    signature: BLSSignature
): BlockHeader {.forceCheck: [].} =
    result = BlockHeader(
        version: version,
        last: last,
        aggregate: aggregate,
        miners: miners,
        time: time,
        proof: proof,
        signature: signature
    )
    result.ffinalizeVersion()
    result.ffinalizeLast()
    result.ffinalizeMiner()
