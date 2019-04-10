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

#Serialization lib,
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Constructor.
func newBlockHeader*(
    nonce: Natural,
    last: ArgonHash,
    verifs: BLSSignature,
    miners: Blake384Hash,
    time: Natural,
    proof: Natural
): BlockHeader {.forceCheck: [
    ArgonError
].} =
    result = newBlockHeaderObj(
        nonce,
        last,
        verifs,
        miners,
        time,
        proof
    )
    try:
        result.hash = Argon(result.serialize(), result.proof.toBinary())
    except ArgonError as e:
        raise e
