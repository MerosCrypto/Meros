discard """
We never send a Difficulty over the Network.

That said, we do store one in the DB, so we need to convert a Difficulty object to a string and back.
Even though this has no relation to the Network code, it does have relation to the Serialize code.
"""

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Miners object.
import ../../../Database/Merit/objects/DifficultyObj

#Common serialization functions.
import ../SerializeCommon

#Serialization function.
func serialize*(
    difficulty: Difficulty
): string {.raises: [].} =
    result =
        !difficulty.start.toBinary() &
        !difficulty.endBlock.toBinary() &
        !difficulty.difficulty.toString(256)
