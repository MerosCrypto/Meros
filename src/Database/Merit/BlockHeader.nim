#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib (for BLSSignature).
import ../../Wallet/MinerWallet

#BlockHeader object.
import objects/BlockHeaderObj
export BlockHeaderObj

#Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Constructor.
func newBlockHeader*(
    nonce: Natural,
    last: ArgonHash,
    aggregate: BLSSignature,
    miners: Blake384Hash,
    time: uint32,
    proof: uint32
): BlockHeader {.forceCheck: [
    ArgonError
].} =
    result = newBlockHeaderObj(
        nonce,
        last,
        aggregate,
        miners,
        time,
        proof
    )
    try:
        result.hash = Argon(result.serializeHash(), result.proof.toBinary())
    except ArgonError as e:
        fcRaise e
