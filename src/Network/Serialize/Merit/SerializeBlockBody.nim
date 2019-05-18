#Errors lib.
import ../../../lib/Errors

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Serialize/Deserialize functions.
import ../SerializeCommon
import SerializeRecords
import SerializeMiners

#Serialize a Block.
proc serialize*(
    body: BlockBody
): string {.forceCheck: [].} =
    result =
        body.records.serialize() &
        body.miners.serialize()
