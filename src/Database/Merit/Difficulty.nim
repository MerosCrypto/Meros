#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BN/Raw lib.
import ../../lib/Raw

#Hash lib.
import ../../lib/Hash

#Blockchain object.
import objects/BlockchainObj

#Block lib.
import Block

#Difficulty object.
import objects/DifficultyObj
export DifficultyObj

#Highest difficulty.
let MAX: BN = "".pad(48, char(255)).toBNFromRaw()

#Verifies a hash beats a difficulty.
proc verify*(
    diff: Difficulty,
    hash: Hash[384]
): bool {.forceCheck: [].} =
    try:
        result = hash > diff.difficulty
    except ValueError:
        return false

#Calculate the next difficulty using the blockchain and blocks per period.
proc calculateNextDifficulty*(
    blockchain: Blockchain,
    blocksPerPeriod: Natural
): Difficulty {.forceCheck: [
    IndexError
].} =
    var
        #Last difficulty.
        last: Difficulty = blockchain.difficulty
        lastDifficulty: BN = last.difficulty.toString().toBNFromRaw()
        #New difficulty.
        difficulty: BN = lastDifficulty
        #Target time.
        targetTime: int = blockchain.blockTime * blocksPerPeriod
        #Start time of this period.
        start: int64
        #End time.
        endTime: int64 = blockchain.tip.header.time
        #Period time.
        actualTime: int64
        #Possible values.
        possible: BN = MAX - lastDifficulty
        #Change.
        change: BN

    #Grab the start time.
    try:
        start = blockchain[blockchain.height - (blocksPerPeriod + 1)].header.time
    except IndexError as e:
        fcRaise e

    #Calculate the actual time.
    actualTime = endTime - start

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
        change = (possible * newBN(targetTime - actualTime)) div newBN(targetTime)

        #If we're increasing the difficulty by more than 10%...
        if possible / newBN(10) < change:
            #Set the change to be 10%.
            change = possible / newBN(10)

        #Set the difficulty.
        difficulty = lastDifficulty + change
    #If we went slower...
    elif actualTime > targetTime:
        #Set the change to be:
            #The invalid values
            #Multipled by the targetTime (smaller)
            #Divided by the actualTime (bigger)
        #Since we need the difficulty to decrease.
        change = lastDifficulty * newBN(targetTime div actualTime)

        #If we're decreasing the difficulty by more than 10% of the possible values...
        if possible / newBN(10) < change:
            #Set the change to be 10% of the possible values.
            change = possible / newBN(10)

        #Set the difficulty.
        difficulty = lastDifficulty - change

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < blockchain.startDifficulty.difficulty.toString().toBNFromRaw():
        difficulty = blockchain.startDifficulty.difficulty.toString().toBNFromRaw()

    #Create the new difficulty.
    try:
        result = newDifficultyObj(
            last.endBlock + 1,
            last.endBlock + blocksPerPeriod,
            difficulty.toRaw().pad(48).toHash(384)
        )
    except ValueError:
        #This is a doAssert false as this problem is due to our half-move off of BNs.
        #This problem (likely) won't exist once we fully move off.
        #That said, this except shouldn't trigger anyways.
        doAssert(false, "Couldn't convert the Difficulty to a Hash.")
