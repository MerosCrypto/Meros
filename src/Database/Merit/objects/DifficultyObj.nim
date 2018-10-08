#BN lib.
import BN as BNFile

#Finals lib.
import finals

#Difficulty object.
finalsd:
    type Difficulty* = ref object of RootObj
        #Start of the period.
        start* {.final.}: int
        #End of the period.
        endBlock* {.final.}: int
        #Difficulty to beat.
        difficulty* {.final.}: BN

#Create a new Difficulty object.
func newDifficultyObj*(start: int, endBlock: int, difficulty: BN): Difficulty {.raises: [].} =
    Difficulty(
        start: start,
        endBlock: endBlock,
        difficulty: difficulty
    )
