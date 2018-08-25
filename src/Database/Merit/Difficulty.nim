#Number libs.
import ../../lib/BN
import ../../lib/Base

#Block lib.
import Block

#String utils standard lib.
import strutils

#OS standard lib.
import os

#Difficulty object.
import objects/DifficultyObj
export DifficultyObj

#Highest difficulty.
let max: BN = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".toBN(16)

#Verifies a difficulty against a block.
proc verifyDifficulty*(diff: Difficulty, newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    #If it's for the wrong time...
    if (diff.getStart() > newBlock.getTime()) or (diff.getEnd() <= newBlock.getTime()):
        return false

    #If the Argon hash didn't beat the difficulty...
    if newBlock.getArgon().toBN(16) < diff.getDifficulty():
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
        if blocks[i].getTime() <= last.getStart():
            break

        #Else, increment the block count for the last period.
        inc(blockCount)

    #If there were as many blocks as the target...
    if blocksPerPeriod == blockCount:
        #Use the same difficulty.
        difficulty = last.getDifficulty()
    #Else if we exceeded the target...
    elif blockCount > blocksPerPeriod:
        var
            #Distance from the max difficulty.
            distance: BN = max - last.getDifficulty()
            #Inverse of the rate (block count / block target).
            rate: BN = (newBN(blocksPerPeriod) * BNNums.HUNDRED) / newBN(blockCount)
            #Amount we're increasing the last difficulty by.
            change: BN = distance * rate / BNNums.HUNDRED

        #Set the difficulty.
        difficulty = last.getDifficulty() + change
    #Else if we didn't meet the target...
    elif blockCount < blocksPerPeriod:
        var
            #Distance from the 'min' difficulty.
            distance: BN = last.getDifficulty()
            #Rate (block count / block target).
            rate: BN = (newBN(blockCount) * BNNums.HUNDRED) / newBN(blocksPerPeriod)
            #Amount we're decreasing the last difficulty by.
            change: BN = distance * rate / BNNums.HUNDRED

        #Set the difficulty.
        difficulty = last.getDifficulty() - change

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < difficulties[0].getDifficulty():
        difficulty = difficulties[0].getDifficulty()

    #Create the new difficulty.
    result = newDifficultyObj(
        last.getEnd(),
        last.getEnd() + newBN(periodInSeconds),
        difficulty
    )
