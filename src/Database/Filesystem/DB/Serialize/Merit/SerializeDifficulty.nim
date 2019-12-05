#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#Difficulty object.
import ../../../../Merit/objects/DifficultyObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialization function.
proc serialize*(
    difficulty: Difficulty
): string {.forceCheck: [].} =
    result =
        difficulty.start.toBinary(INT_LEN) &
        difficulty.endHeight.toBinary(INT_LEN) &
        difficulty.difficulty.toString()
