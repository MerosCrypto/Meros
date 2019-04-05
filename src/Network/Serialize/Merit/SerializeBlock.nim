#Block lib.
import ../../../Database/Merit/Block

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeVerifications
import SerializeMiners

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [].} =
    #Create the serialized Block.
    result =
        blockArg.header.serialize() &
        blockArg.verifications.serialize() &
        blockArg.miners.serialize()
