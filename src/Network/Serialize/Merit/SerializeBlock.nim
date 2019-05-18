#Errors lib.
import ../../../lib/Errors

#Block lib.
import ../../../Database/Merit/Block

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeBlockBody

#Serialize a Block.
proc serialize*(
    blockArg: Block
): string {.forceCheck: [].} =
    result =
        blockArg.header.serialize() &
        blockArg.body.serialize()
