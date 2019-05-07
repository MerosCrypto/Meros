#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BN/Raw lib.
import ../../../lib/Raw

#Hash lib.
import ../../../lib/Hash

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
        difficulty* {.final.}: Hash[384]

#Create a new Difficulty object.
func newDifficultyObj*(
    start: Natural,
    endBlock: Natural,
    difficulty: Hash[384]
): Difficulty {.forceCheck: [].} =
    result = Difficulty(
        start: start,
        endBlock: endBlock,
        difficulty: difficulty
    )
    result.ffinalizeStart()
    result.ffinalizeEndBlock()
    result.ffinalizeDifficulty()

proc newDifficultyObj*(
    start: Natural,
    endBlock: Natural,
    difficulty: BN
): Difficulty {.forceCheck: [].} =
    try:
        result = newDifficultyObj(
            start,
            endBlock,
            difficulty.toRaw().pad(48).toHash(384)
        )
    except ValueError:
        #This is a doAssert false as this entire method will be deleted as soon as Difficulty no longer requires BNs.
        doAssert(false, "newDifficultyObj failed to create a hash.")
