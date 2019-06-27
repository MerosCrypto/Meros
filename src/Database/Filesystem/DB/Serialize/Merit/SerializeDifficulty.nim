#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#Difficulty object.
import ../../../..//Merit/objects/DifficultyObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

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
