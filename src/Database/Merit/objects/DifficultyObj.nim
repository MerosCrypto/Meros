#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Difficulty object.
type Difficulty* = object
    #Start of the period.
    start*: int
    #End of the period.
    endHeight*: int
    #Difficulty to beat.
    difficulty*: Hash[256]

#Constructor.
func newDifficultyObj*(
    start: int,
    endHeight: int,
    difficulty: Hash[256]
): Difficulty {.inline, forceCheck: [].} =
    Difficulty(
        start: start,
        endHeight: endHeight,
        difficulty: difficulty
    )
