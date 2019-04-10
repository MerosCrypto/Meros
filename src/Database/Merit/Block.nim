#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BlockHeader lib.
import BlockHeader

#Block object.
import objects/BlockObj
export BlockObj

#Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Increase the proof.
func inc*(
    blockArg: var Block
) {.forceCheck: [
    ArgonError
].} =
    #Increase the proof.
    inc(blockArg.header.proof)
    #Recalculate the hash.
    try:
        blockArg.header.hash = Argon(blockArg.header.serialize(), blockArg.header.proof.toBinary())
    except ArgonError as e:
        raise e
