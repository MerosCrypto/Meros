#Errors lib.
import ../../../lib/Errors

#Block lib.
import ../../../Database/Merit/Block

#Serialize functions.
import SerializeBlockHeader
import SerializeBlockBody

#Serialize a Block.
proc serialize*(
    blockArg: Block
): string {.forceCheck: [
    ValueError
].} =
    try:
        result =
            blockArg.header.serialize() &
            blockArg.body.serialize(blockArg.header.sketchSalt)
    except ValueError as e:
        raise e
