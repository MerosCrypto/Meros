discard """
Read the note in SerializeDifficulty before working with this file.
"""

#Util lib.
import ../../../lib/Util

#Numerical libs.
import BN
import ../../../lib/Base

#Difficulty object.
import ../../../Database/Merit/objects/DifficultyObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseDifficulty*(
    difficultyStr: string
): Difficulty {.raises: [ValueError].} =
    #Start | End | Difficulty
    var difficultySeq: seq[string] = difficultyStr.deserialize(
        INT_LEN,
        INT_LEN,
        HASH_LEN
    )

    #Add each miner/amount.
    result = newDifficultyObj(
        uint(difficultySeq[0].fromBinary()),
        uint(difficultySeq[1].fromBinary()),
        difficultySeq[2].toBN(256)
    )
