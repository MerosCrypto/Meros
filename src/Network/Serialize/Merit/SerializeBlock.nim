#Block lib.
import ../../../Database/Merit/Block

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeIndexes
import SerializeMiners

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [].} =
    result =
        blockArg.header.serialize() &
        blockArg.indexes.serialize() &
        blockArg.miners.serialize()
