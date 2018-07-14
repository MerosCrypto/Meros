#Number libs.
import BN
import ../lib/Hex

#Block lib.
import Block as BlockFile

#Lists standard lib and string utils.
import lists, strutils

#OS standard lib.
import os

#Difficulty object.
type Difficulty* = ref object of RootObj
    #Start of the period.
    start*: BN
    #End of the period.
    endTime*: BN
    #Difficulty to beat.
    difficulty*: BN

#Verifies a difficulty against a block.
proc verifyDifficulty*(diff: Difficulty, newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    #If it's for the wrong time...
    if (diff.start > newBlock.getTime()) or (diff.endTime <= newBlock.getTime()):
        result = false
        return

    #If the Lyra hash didn't beat the difficulty...
    if Hex.revert(newBlock.getLyra()) < diff.difficulty:
        result = false
        return

#Calculate the next difficulty using the blocks, difficulties, period Length, and blocks per period.
proc calculateNextDifficulty*(
    blocks: DoublyLinkedList[Block],
    difficulties: DoublyLinkedList[Difficulty],
    periodInSeconds: int,
    blocksPerPeriod: int
): Difficulty {.raises: [AssertionError].} =
    var
        #Last difficulty.
        last: Difficulty = difficulties.tail.value
        #Blocks in the last period.
        blockCount: int = 0
        rate: float64
        difficulty: BN

    #Iterate through every block.
    for b in items(blocks):
        #Continue if the b is out of the period.
        if (b.getTime() < last.start) or (last.endTime <= b.getTime()):
            continue
        #Else, increment the block count for the last period.
        inc(blockCount)

    #If the blocks per period target is less than the count...
    if blocksPerPeriod < blockCount:
        #The rate is the block count over the target blocks per period.
        rate = blockCount / blocksPerPeriod
    #Else, if there were as many blocks as the target...
    elif blocksPerPeriod == blockCount:
        #Use the same difficulty.
        result = Difficulty(
            start: last.endTime,
            endTime: last.endTime + newBN($periodInSeconds),
            difficulty: last.difficulty
        )
        return
    #Else, if the count was less than the blocks per period target...
    elif blockCount < blocksPerPeriod:
        #The rate is the target blocks per period over the block count.
        rate = blocksPerPeriod / blockCount

    #If the block count was 0 (divide by 0), set the rate to 10.
    #This will cause the difficulty to be divided by 10.
    if blockCount == 0:
        rate = 10

    #Get a BN out of the rate.
    var bnRate: BN = newBN(($rate).split(".")[0])
    #If the count was lower than the target...
    if blockCount < blocksPerPeriod:
        #The difficulty is the last one divided by the rate.
        difficulty = last.difficulty / bnRate
    #Else, if the count was higher than the target...
    elif blockCount > blocksPerPeriod:
        #The difficulty is the last one multiplied by the rate.
        difficulty = last.difficulty * bnRate

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < difficulties.head.value.difficulty:
        difficulty = difficulties.head.value.difficulty

    #Create the new difficulty.
    result = Difficulty(
        start: last.endTime,
        endTime: last.endTime + newBN($periodInSeconds),
        difficulty: difficulty
    )
