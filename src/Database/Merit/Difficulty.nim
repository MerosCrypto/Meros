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

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#OS standard lib.
import os

#Highest difficulty.
let max: BN = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".toBN(16)

#Verifies a difficulty against a block.
proc verifyDifficulty*(diff: Difficulty, newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    #If it's for the wrong time...
    if (diff.start > newBlock.time) or (diff.endTime <= newBlock.time):
        return false

    #If the Argon hash didn't beat the difficulty...
    if newBlock.argon.toBN() < diff.difficulty:
        return false

#Calculate the next difficulty using the blocks, difficulties, period Length, and blocks per period.
proc calculateNextDifficulty*(
    blocks: seq[Block],
    difficulties: seq[Difficulty],
    periodInSeconds: int,
    blocksPerPeriod: int
): Difficulty {.raises: [ValueError].} =
    var
        #Last difficulty.
        last: Difficulty = difficulties[difficulties.len-1]
        #Blocks in the last period.
        blockCount: int = 0
        difficulty: BN

    #Iterate through every block.
    var b: Block
    #Stop at 0. This is a while loop because countdown wasn't behaving properly.
    for i in countdown(blocks.len - 1, 0):
        #Break if the block is out of the period.
        if blocks[i].time <= last.start:
            break

        #Else, increment the block count for the last period.
        inc(blockCount)

    #If there were as many blocks as the target...
    if blocksPerPeriod == blockCount:
        #Use the same difficulty.
        difficulty = last.difficulty
    #Else if we exceeded the target...
    elif blockCount > blocksPerPeriod:
        var
            #Distance from the max difficulty.
            distance: BN = max - last.difficulty
            #Inverse of the rate (block count / block target).
            rate: BN = (newBN(blocksPerPeriod) * BNNums.HUNDRED) / newBN(blockCount)
            #Amount we're increasing the last difficulty by.
            change: BN = distance * rate / BNNums.HUNDRED

        #Set the difficulty.
        difficulty = last.difficulty + change
    #Else if we didn't meet the target...
    elif blockCount < blocksPerPeriod:
        var
            #Distance from the 'min' difficulty.
            distance: BN = last.difficulty
            #Rate (block count / block target).
            rate: BN = (newBN(blockCount) * BNNums.HUNDRED) / newBN(blocksPerPeriod)
            #Amount we're decreasing the last difficulty by.
            change: BN = distance * rate / BNNums.HUNDRED

        #Set the difficulty.
        difficulty = last.difficulty - change

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < difficulties[0].difficulty:
        difficulty = difficulties[0].difficulty

    #Create the new difficulty.
    result = newDifficultyObj(
        last.endTime,
        last.endTime + newBN(periodInSeconds),
        difficulty
    )
