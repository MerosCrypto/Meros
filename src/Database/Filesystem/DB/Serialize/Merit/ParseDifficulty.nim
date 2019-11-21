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

#Parse function.
proc parseDifficulty*(
    difficultyStr: string
): Difficulty {.forceCheck: [
    ValueError
].} =
    #Start | End | Difficulty
    var difficultySeq: seq[string] = difficultyStr.deserialize(
        INT_LEN,
        INT_LEN,
        HASH_LEN
    )

    #Create the Difficulty.
    try:
        result = newDifficultyObj(
            difficultySeq[0].fromBinary(),
            difficultySeq[1].fromBinary(),
            difficultySeq[2].toHash(384)
        )
    except ValueError as e:
        fcRaise e
