#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BlockHeader lib and Block object.
import BlockHeader
import objects/BlockObj
#Export the BlockHeader and Block objects.
export BlockHeader
export BlockObj

#Serialization lib.
import ../../Network/Serialize/Merit/SerializeBlockHeader

#Finals lib.
import finals

#Increase the proof.
proc inc*(newBlock: Block) {.raises: [ArgonError].} =
    #Increase the proof.
    inc(newBlock.header.proof)

    #Recalculate the hash.
    newBlock.header.hash = Argon(newBlock.header.serialize(), newBlock.header.proof.toBinary())
