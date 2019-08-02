#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Blockchain object.
import objects/BlockchainObj

#Block lib.
import Block

#Difficulty object.
import objects/DifficultyObj
export DifficultyObj

#StInt lib.
import StInt

let
    #Ten.
    TEN: StUint[512] = stuint(10, 512)
    #Highest difficulty.
    MAX: StUint[512] = "".pad(96, 'F').parse(StUint[512], 16)

#Verifies a hash beats a difficulty.
proc verify*(
    diff: Difficulty,
    hash: Hash[384]
): bool {.forceCheck: [].} =
    try:
        result = hash > diff.difficulty.toByteArrayBE()[16 .. 63].toHash(384)
    except ValueError:
        result = false

#Calculate the next difficulty using the blockchain and blocks per period.
proc calculateNextDifficulty*(
    blockchain: Blockchain,
    blocksPerPeriod: int
): Difficulty {.forceCheck: [
    IndexError
].} =
    var
        #Last difficulty.
        last: Difficulty = blockchain.difficulty
        #New difficulty.
        difficulty: StUint[512] = last.difficulty
        #Target time.
        targetTime: uint32 = uint32(blockchain.blockTime * blocksPerPeriod)
        #Start time of this period.
        start: uint32
        #End time.
        endTime: uint32 = blockchain.tip.header.time
        #Period time.
        actualTime: uint32
        #Possible values.
        possible: StUint[512] = MAX - last.difficulty
        #Change.
        change: StUint[512]

    #Grab the start time.
    try:
        start = blockchain[blockchain.height - (blocksPerPeriod + 1)].header.time
    except IndexError as e:
        fcRaise e

    #Calculate the actual time.
    actualTime = endTime - start

    try:
        #If we went faster...
        if actualTime < targetTime:
            #Set the change to be:
                #The possible values multipled by
                    #The targetTime (bigger) minus the actualTime (smaller)
                    #Over the targetTime
            #Since we need the difficulty to increase.
            change = (possible * stuint(targetTime - actualTime, 512)) div stuint(targetTime, 512)

            #If we're increasing the difficulty by more than 10%...
            if possible div TEN < change:
                #Set the change to be 10%.
                change = possible div TEN

            #Set the difficulty.
            difficulty = last.difficulty + change
        #If we went slower...
        elif actualTime > targetTime:
            #Set the change to be:
                #The invalid values
                #Multipled by the targetTime (smaller)
                #Divided by the actualTime (bigger)
            #Since we need the difficulty to decrease.
            change = last.difficulty * stuint(targetTime div actualTime, 512)

            #If we're decreasing the difficulty by more than 10% of the possible values...
            if possible div TEN < change:
                #Set the change to be 10% of the possible values.
                change = possible div TEN

            #Set the difficulty.
            difficulty = last.difficulty - change
    except DivByZeroError as e:
        doAssert(false, "Dividing by ten raised a DivByZeroError: " & e.msg)

    #If the difficulty is lower than the starting difficulty, use that.
    if difficulty < blockchain.startDifficulty.difficulty:
        difficulty = blockchain.startDifficulty.difficulty

    #Create the new difficulty.
    try:
        result = newDifficultyObj(
            last.endBlock + 1,
            last.endBlock + blocksPerPeriod,
            difficulty
        )
    except ValueError:
        #This is a doAssert false as this problem is due to our half-move off of BNs.
        #This problem (likely) won't exist once we fully move off.
        #That said, this except shouldn't trigger anyways.
        doAssert(false, "Couldn't convert the Difficulty to a Hash.")
