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
        start* {.final.}: int
        #End of the period.
        endHeight* {.final.}: int
        #Difficulty to beat.
        difficulty* {.final.}: StUint[512]

#Constructors.
func newDifficultyObj*(
    start: int,
    endHeight: int,
    difficulty: StUint[512]
): Difficulty {.forceCheck: [].} =
    result = Difficulty(
        start: start,
        endHeight: endHeight,
        difficulty: difficulty
    )
    result.ffinalizeStart()
    result.ffinalizeEndBlock()
    result.ffinalizeDifficulty()

func newDifficultyObj*(
    start: int,
    endHeight: int,
    difficulty: Hash[384]
): Difficulty {.forceCheck: [
    ValueError
].} =
    try:
        result = newDifficultyObj(
            start,
            endHeight,
            ($difficulty).parse(StUint[512], 16)
        )
    except ValueError as e:
        fcRaise e
