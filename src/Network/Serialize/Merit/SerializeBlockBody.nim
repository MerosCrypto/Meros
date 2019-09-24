#Errors lib.
import ../../../lib/Errors

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Serialize a Block.
proc serialize*(
    body: BlockBody
): string {.forceCheck: [].} =
    ""
