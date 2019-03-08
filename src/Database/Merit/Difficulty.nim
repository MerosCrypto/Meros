#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Blockchain object.
import objects/BlockchainObj

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
#This would be in Main's Constants except it's impossible to change without changing the underlying libraries.
let MAX: BN = "F".repeat(128).toBN(16)

#Verifies a difficulty against a block.
func verifyDifficulty*(diff: Difficulty, newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    #If the Argon hash didn't beat the difficulty...
    if newBlock.hash.toBN() < diff.difficulty:
        return false

#Calculate the next difficulty using the blockchain and blocks per period.
proc calculateNextDifficulty*(
    blockchain: Blockchain,
    blocksPerPeriod: uint
): Difficulty {.raises: [].} =
    #If it was the genesis block, keep the same difficulty.
    if blockchain.height == 1:
        return blockchain.difficulties[0]

    var
        #Last difficulty.
        last: Difficulty = blockchain.difficulties[^1]
        #New difficulty.
        difficulty: BN = last.difficulty
        #Target time.
        targetTime: uint = blockchain.blockTime * blocksPerPeriod
        #Start block of the difficulty.
        start: uint = blockchain[blockchain.height - (blocksPerPeriod + 1)].header.time
        #End block of the difficulty.
        endTime: uint = blockchain.tip.header.time
        #Period time.
        actualTime: uint = endTime - start
        #Possible values.
        possible: BN = MAX - last.difficulty

    #Handle divide by zeros.
    if actualTime == 0:
        actualTime = 1

    #If we went faster...
    if actualTime < targetTime:
        #Set the change to be:
            #The possible values multipled by
                #The targetTime (bigger) minus the actualTime (smaller)
                #Over the targetTime
        #Since we need the difficulty to increase.
        var change: BN = (possible * newBN(targetTime - actualTime)) div newBN(targetTime)

        #If we're increasing the difficulty by more than 10%...
        if possible / newBN(10) < change:
            #Set the change to be 10%.
            change = possible / newBN(10)

        #Set the difficulty.
        difficulty = last.difficulty + change
    #If we went slower...
    elif actualTime > targetTime:
        #Set the change to be:
            #The invalid values
            #Multipled by the targetTime (smaller)
            #Divided by the actualTime (bigger)
        #Since we need the difficulty to decrease.
        var change: BN = last.difficulty * newBN(targetTime div actualTime)

        #If we're decreasing the difficulty by more than 10% of the possible values...
        if possible / newBN(10) < change:
            #Set the change to be 10% of the possible values.
            change = possible / newBN(10)

        #Set the difficulty.
        difficulty = last.difficulty - change

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < blockchain.difficulties[0].difficulty:
        difficulty = blockchain.difficulties[0].difficulty

    #Create the new difficulty.
    result = newDifficultyObj(
        last.endBlock,
        last.endBlock + blocksPerPeriod,
        difficulty
    )
