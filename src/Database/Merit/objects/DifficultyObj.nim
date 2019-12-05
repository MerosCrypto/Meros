#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

#Difficulty object.
finalsd:
    type Difficulty* = object
        #Start of the period.
        start* {.final.}: int
        #End of the period.
        endHeight* {.final.}: int
        #Difficulty to beat.
        difficulty* {.final.}: Hash[384]

#Constructor.
func newDifficultyObj*(
    start: int,
    endHeight: int,
    difficulty: Hash[384]
): Difficulty {.forceCheck: [].} =
    result = Difficulty(
        start: start,
        endHeight: endHeight,
        difficulty: difficulty
    )
    result.ffinalizeStart()
    result.ffinalizeEndHeight()
    result.ffinalizeDifficulty()
