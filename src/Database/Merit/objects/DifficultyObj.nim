#BN lib.
import BN

#Finals lib.
import finals

#Difficulty object.
finalsd:
    type Difficulty* = ref object of RootObj
        #Start of the period.
        start* {.final.}: uint
        #End of the period.
        endBlock* {.final.}: uint
        #Difficulty to beat.
        difficulty* {.final.}: BN

#Create a new Difficulty object.
func newDifficultyObj*(start: uint, endBlock: uint, difficulty: BN): Difficulty {.raises: [].} =
    Difficulty(
        start: start,
        endBlock: endBlock,
        difficulty: difficulty
    )
