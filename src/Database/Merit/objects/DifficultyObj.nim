#BN lib.
import ../../../lib/BN

#Difficulty object.
type Difficulty* = ref object of RootObj
    #Start of the period.
    start: BN
    #End of the period.
    endTime: BN
    #Difficulty to beat.
    difficulty: BN

#Create a new Difficulty object.
proc newDifficultyObj*(start: BN, endTime: BN, difficulty: BN): Difficulty {.raises: [].} =
    Difficulty(
        start: start,
        endTime: endTime,
        difficulty: difficulty
    )

#Getters.
proc getStart*(diff: Difficulty): BN {.raises: [].} =
    diff.start
proc getEnd*(diff: Difficulty): BN {.raises: [].} =
    diff.endTime
proc getDifficulty*(diff: Difficulty): BN {.raises: [].} =
    diff.difficulty
