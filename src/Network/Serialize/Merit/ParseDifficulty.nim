discard """
Read the note in SerializeDifficulty before working with this file.
"""

#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw

#Difficulty object.
import ../../../Database/Merit/objects/DifficultyObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseDifficulty*(
    difficultyStr: string
): Difficulty {.forceCheck: [], fcBoundsOverride.} =
    #Start | End | Difficulty
    var difficultySeq: seq[string] = difficultyStr.deserialize(
        INT_LEN,
        INT_LEN,
        HASH_LEN
    )

    #Add each miner/amount.
    result = newDifficultyObj(
        difficultySeq[0].fromBinary(),
        difficultySeq[1].fromBinary(),
        difficultySeq[2].toBNFromRaw()
    )
