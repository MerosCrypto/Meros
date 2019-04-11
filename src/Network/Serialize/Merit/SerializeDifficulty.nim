discard """
We never send a Difficulty over the Network.

That said, we do store one in the DB, so we need to convert a Difficulty object to a string and back.
Even though this has no relation to the Network code, it does have relation to the Serialize code.
"""

#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw
import ../../../lib/Hex

#Miners object.
import ../../../Database/Merit/objects/DifficultyObj

#Common serialization functions.
import ../SerializeCommon

#Serialization function.
proc serialize*(
    difficulty: Difficulty
): string {.forceCheck: [].} =
    result =
        difficulty.start.toBinary().pad(INT_LEN) &
        difficulty.endBlock.toBinary().pad(INT_LEN) &
        difficulty.difficulty.toRaw().pad(HASH_LEN)
