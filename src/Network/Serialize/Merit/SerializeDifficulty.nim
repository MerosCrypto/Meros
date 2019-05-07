discard """
We never send a Difficulty over the Network.

That said, we do store one in the DB, so we need to convert a Difficulty object to a string and back.
Even though this has no relation to the Network code, it does have relation to the Serialize code.
"""

#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Difficulty object.
import ../../../Database/Merit/objects/DifficultyObj

#Common serialization functions.
import ../SerializeCommon

#StInt lib.
import StInt

#Serialization function.
proc serialize*(
    difficulty: Difficulty
): string {.forceCheck: [].} =
    result =
        difficulty.start.toBinary().pad(INT_LEN) &
        difficulty.endBlock.toBinary().pad(INT_LEN)

    var bytes: array[64, byte] = difficulty.difficulty.toByteArrayBE()
    for i in 16 ..< bytes.len:
        result &= char(bytes[i])
