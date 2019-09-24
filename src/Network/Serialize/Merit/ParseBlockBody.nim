#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BlockBody object.
import ../../../Database/Merit/objects/BlockBodyObj

#Deserialize/parse functions.
import ../SerializeCommon

#Parse a BlockBody.
proc parseBlockBody*(
    bodyStr: string
): BlockBody {.forceCheck: [].} =
    discard
