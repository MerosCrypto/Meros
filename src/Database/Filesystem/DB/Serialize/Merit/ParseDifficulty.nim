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

#StInt lib.
import StInt

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
        DIFFICULTY_LEN
    )

    #Create the Difficulty.
    if difficultySeq[2].len < 48:
        raise newException(ValueError, "parseDifficulty not handed enough data to get the difficulty.")

    var be: array[64, byte]
    for i in 16 ..< 64:
        be[i] = byte(difficultySeq[2][i - 16])

    try:
        result = newDifficultyObj(
            difficultySeq[0].fromBinary(),
            difficultySeq[1].fromBinary(),
            fromBytesBE(StUint[512], be)
        )
    except ValueError as e:
        fcRaise e
