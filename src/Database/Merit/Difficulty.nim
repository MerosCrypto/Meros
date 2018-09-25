#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Block lib.
import Block
#Difficulty object.
import objects/DifficultyObj
export DifficultyObj

#String utils standard lib.
import strutils

#OS standard lib.
import os

#Highest difficulty.
let MAX: BN = "F".repeat(128).toBN(16)

#Verifies a difficulty against a block.
proc verifyDifficulty*(diff: Difficulty, newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    #If the Argon hash didn't beat the difficulty...
    if newBlock.argon.toBN() < diff.difficulty:
        return false

#Calculate the next difficulty using the blocks, difficulties, period Length, and blocks per period.
proc calculateNextDifficulty*(
    blocks: seq[Block],
    difficulties: seq[Difficulty],
    targetTime: BN,
    blocksPerPeriod: int
): Difficulty {.raises: [].} =
    #If it was the genesis block, keep the same difficulty.
    if blocks.len == 1:
        return difficulties[0]

    var
        #Last difficulty.
        last: Difficulty = difficulties[difficulties.len-1]
        #New difficulty.
        difficulty: BN = last.difficulty
        #Start time of the difficulty (the block before this difficulty).
        start: BN = blocks[blocks.len - (blocksPerPeriod + 1)].time
        #End time of the difficulty (the last block).
        endTime: BN = blocks[blocks.len - 1].time
        #Period time.
        actualTime: BN = endTime - start
        #Possible values.
        possible: BN = MAX - last.difficulty

    #Handle divide by zeros.
    if actualTime == BNNums.ZERO:
        actualTime = BNNums.ONE

    #If we went faster...
    if actualTime < targetTime:
        #Set the change to be:
            #The possible values multipled by
                #The targetTime (bigger) minus the actualTime (smaller)
                #Over the targetTime
        #Since we need the difficulty to increase.
        var change: BN = possible * (targetTime - actualTime) / targetTime

        #If we're increasing the difficulty by more than 10%...
        if possible / BNNums.TEN < change:
            #Set the change to be 10%.
            change = possible / BNNums.TEN

        #Set the difficulty.
        difficulty = last.difficulty + change
    #If we went slower...
    elif actualTime > targetTime:
        #Set the change to be:
            #The invalid values
            #Multipled by the targetTime (smaller)
            #Divided by the actualTime (bigger)
        #Since we need the difficulty to decrease.
        var change: BN = last.difficulty * targetTime / actualTime

        #If we're decreasing the difficulty by more than 10% of the possible values...
        if possible / BNNums.TEN < change:
            #Set the change to be 10% of the possible values.
            change = possible / BNNums.TEN

        #Set the difficulty.
        difficulty = last.difficulty - change

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < difficulties[0].difficulty:
        difficulty = difficulties[0].difficulty

    #Create the new difficulty.
    result = newDifficultyObj(
        last.endBlock,
        last.endBlock + newBN(blocksPerPeriod),
        difficulty
    )
