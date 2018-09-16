#BN lib.
import BN as BNFile

#SetOnce lib.
import SetOnce

#Difficulty object.
type Difficulty* = ref object of RootObj
    #Start of the period.
    start*: SetOnce[BN]
    #End of the period.
    endBlock*: SetOnce[BN]
    #Difficulty to beat.
    difficulty*: SetOnce[BN]

#Create a new Difficulty object.
proc newDifficultyObj*(start: BN, endBlock: BN, difficulty: BN): Difficulty {.raises: [ValueError].} =
    result = Difficulty()
    result.start.value = start
    result.endBlock.value = endBlock
    result.difficulty.value = difficulty
