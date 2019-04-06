#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#BlockHeader object.
import objects/BlockHeaderObj
export BlockHeaderObj

#Serialization lib,
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Constructor.
proc newBlockHeader*(
    nonce: uint,
    last: ArgonHash,
    verifs: BLSSignature,
    miners: Blake384Hash,
    time: uint,
    proof: uint
): BlockHeader {.raises: [ArgonError].} =
    result = newBlockHeaderObj(
        nonce,
        last,
        verifs,
        miners,
        time,
        proof
    )
    result.hash = Argon(result.serialize(), result.proof.toBinary())
