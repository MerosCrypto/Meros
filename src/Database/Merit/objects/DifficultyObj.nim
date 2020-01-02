#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Difficulty object.
type Difficulty* = object
    #Start of the period.
    start*: int
    #End of the period.
    endHeight*: int
    #Difficulty to beat.
    difficulty*: Hash[384]

#Constructor.
func newDifficultyObj*(
    start: int,
    endHeight: int,
    difficulty: Hash[384]
): Difficulty {.inline, forceCheck: [].} =
    Difficulty(
        start: start,
        endHeight: endHeight,
        difficulty: difficulty
    )
