#Errors lib.
import ../../lib/Errors

#BlockHeader and Block objects.
import ../Merit/objects/BlockHeaderObj
import ../Merit/objects/BlockObj

#Serialization libs.
import ../../Network/Serialize/Merit/SerializeBlock
import ../../Network/Serialize/Merit/SerializeDifficulty

import ../../Network/Serialize/Merit/ParseBlockHeader
import ../../Network/Serialize/Merit/ParseBlock
import ../../Network/Serialize/Merit/ParseDifficulty

#DB lib.
import DB

proc save*(
    db: DB,
    header: BlockHeader
): {.forceCheck: [].} =
    discard

proc save*(
    db: DB,
    blockArg: Block
): {.forceCheck: [].} =
    discard

proc save*(
    db: DB,
    difficulty: Difficulty
): {.forceCheck: [].} =
    discard

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
