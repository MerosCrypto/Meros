#Errors lib.
import ../../../lib/Errors

#BN lib.
import BN

#Finals lib.
import finals

#Difficulty object.
finalsd:
    type Difficulty* = object
        #Start of the period.
        start* {.final.}: Natural
        #End of the period.
        endBlock* {.final.}: Natural
        #Difficulty to beat.
        difficulty* {.final.}: BN

#Create a new Difficulty object.
func newDifficultyObj*(
    start: Natural,
    endBlock: Natural,
    difficulty: BN
): Difficulty {.forceCheck: [].} =
    result = Difficulty(
        start: start,
        endBlock: endBlock,
        difficulty: difficulty
    )
    result.ffinalizeStart()
    result.ffinalizeEndBlock()
    result.ffinalizeDifficulty()
