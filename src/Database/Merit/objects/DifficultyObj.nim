#BN lib.
import BN as BNFile

#SetOnce lib.
import SetOnce

#Difficulty object.
type Difficulty* = ref object of RootObj
    #Start of the period.
    start*: SetOnce[BN]
    #End of the period.
    endTime*: SetOnce[BN]
    #Difficulty to beat.
    difficulty*: SetOnce[BN]

#Create a new Difficulty object.
proc newDifficultyObj*(start: BN, endTime: BN, difficulty: BN): Difficulty {.raises: [ValueError].} =
    result = Difficulty()
    result.start.value = start
    result.endTime.value = endTime
    result.difficulty.value = difficulty
