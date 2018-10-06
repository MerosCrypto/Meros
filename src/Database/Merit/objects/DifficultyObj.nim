#BN lib.
import BN as BNFile

#Finals lib.
import finals

#Difficulty object.
finalsd:
    type Difficulty* = ref object of RootObj
        #Start of the period.
        start* {.final.}: BN
        #End of the period.
        endBlock* {.final.}: BN
        #Difficulty to beat.
        difficulty* {.final.}: BN

#Create a new Difficulty object.
func newDifficultyObj*(start: BN, endBlock: BN, difficulty: BN): Difficulty {.raises: [].} =
    Difficulty(
        start: start,
        endBlock: endBlock,
        difficulty: difficulty
    )
