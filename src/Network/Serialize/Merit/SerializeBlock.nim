#Errors lib.
import ../../../lib/Errors

#Block lib.
import ../../../Database/Merit/Block

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeBlockHeader
import SerializeRecords
import SerializeMiners

#Serialize a Block.
proc serialize*(
    blockArg: Block
): string {.forceCheck: [].} =
    result =
        blockArg.header.serialize() &
        blockArg.records.serialize() &
        blockArg.miners.serialize()
