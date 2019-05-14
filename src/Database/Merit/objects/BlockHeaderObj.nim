#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib (for BLSSignature).
import ../../../Wallet/MinerWallet

#Miners object.
import MinersObj

#Finals lib.
import finals

finalsd:
    #Define the BlockHeader object.
    type BlockHeader* = object
        #Block hash.
        hash*: ArgonHash

        #Nonce.
        nonce* {.final.}: Natural
        #Argon hash of the last block.
        last* {.final.}: ArgonHash

        #Aggregate Signatue of the Elements.
        aggregate*: BLSSignature
        #Merkle tree hash of the Miners.
        miners*: Blake384Hash

        #Timestamp.
        time*: Time
        #Proof.
        proof*: Natural

#Constructor.
func newBlockHeaderObj*(
    nonce: Natural,
    last: ArgonHash,
    aggregate: BLSSignature,
    miners: Blake384Hash,
    time: Time,
    proof: Natural
): BlockHeader {.forceCheck: [].} =
    result = BlockHeader(
        nonce: nonce,
        last: last,
        aggregate: aggregate,
        miners: miners,
        time: time,
        proof: proof
    )

    result.ffinalizeNonce()
    result.ffinalizeLast()
