#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#BlockHeader and Block objects.
import objects/BlockHeaderObj
import objects/BlockObj
#Export the BlockHeader and Block objects.
export BlockHeaderObj
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
    newBlock.hash = Argon(newBlock.header.serialize(), newBlock.header.proof.toBinary())
