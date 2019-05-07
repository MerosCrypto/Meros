#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Finals lib.
import finals

#StInt lib.
import StInt

#Difficulty object.
finalsd:
    type Difficulty* = object
        #Start of the period.
        start* {.final.}: Natural
        #End of the period.
        endBlock* {.final.}: Natural
        #Difficulty to beat.
        difficulty* {.final.}: StUint[512]

#Constructors.
func newDifficultyObj*(
    start: Natural,
    endBlock: Natural,
    difficulty: StUint[512]
): Difficulty {.forceCheck: [].} =
    result = Difficulty(
        start: start,
        endBlock: endBlock,
        difficulty: difficulty
    )
    result.ffinalizeStart()
    result.ffinalizeEndBlock()
    result.ffinalizeDifficulty()

func newDifficultyObj*(
    start: Natural,
    endBlock: Natural,
    difficulty: Hash[384]
): Difficulty {.forceCheck: [
    ValueError
].} =
    try:
        result = newDifficultyObj(
            start,
            endBlock,
            ($difficulty).pad(128, '0').parse(StUint[512], 16)
        )
    except ValueError as e:
        raise e
