#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Blockchain object.
import objects/BlockchainObj

#Difficulty object.
import objects/DifficultyObj
export DifficultyObj

#StInt lib.
import StInt

let
    #Ten.
    TEN: StUint[256] = stuint(10, 256)
    #Highest difficulty.
    MAX: StUint[256] = "".pad(64, 'F').parse(StUint[256], 16)

#Calculate the next difficulty using the blockchain and blocks per period.
proc calculateNextDifficulty*(
    blockchain: Blockchain,
    blocksPerPeriod: int
): Difficulty {.forceCheck: [].} =
    var
        #Last difficulty.
        last: Difficulty = blockchain.difficulty
        #New difficulty.
        difficulty: StUint[256]

    #Convert the difficulty to a StUInt.
    try:
         difficulty = ($last.difficulty).parse(StUInt[256], 16)
    except ValueError as e:
        doAssert(false, "Couldn't parse a hash into a StUint: " & e.msg)

    var
        #Final difficulty.
        difficultyHash: Hash[256]
        #Target time.
        targetTime: uint32 = uint32(blockchain.blockTime * blocksPerPeriod)
        #Start time of this period.
        start: uint32
        #End time.
        endTime: uint32 = blockchain.tail.header.time
        #Period time.
        actualTime: uint32
        #Possible values.
        possible: StUint[256] = MAX - difficulty
        #Change.
        change: StUint[256]

    #Grab the start time.
    try:
        start = blockchain[blockchain.height - (blocksPerPeriod + 1)].header.time
    except IndexError:
        doAssert(false, "Couldn't grab the Block which started this period.")

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
            change = (possible * stuint(targetTime - actualTime, 256)) div stuint(targetTime, 256)

            #If we're increasing the difficulty by more than 10%...
            if possible div TEN < change:
                #Set the change to be 10%.
                change = possible div TEN

            #Set the difficulty.
            difficulty += change
        #If we went slower...
        elif actualTime > targetTime:
            #Set the change to be:
                #The invalid values
                #Multipled by the targetTime (smaller)
                #Divided by the actualTime (bigger)
            #Since we need the difficulty to decrease.
            change = difficulty * stuint(targetTime div actualTime, 256)

            #If we're decreasing the difficulty by more than 10% of the possible values...
            if possible div TEN < change:
                #Set the change to be 10% of the possible values.
                change = possible div TEN

            #Set the difficulty.
            difficulty -= change
    except DivByZeroError as e:
        doAssert(false, "Dividing by ten raised a DivByZeroError: " & e.msg)

    #Convert the difficulty to a hash.
    try:
        difficultyHash = dumpHex(difficulty).toHash(256)
    except ValueError as e:
        doAssert(false, "Couldn't convert a StUInt to a hash: " & e.msg)

    #If the difficulty is lower than the starting difficulty, use that.
    if difficultyHash < blockchain.startDifficulty.difficulty:
        difficultyHash = blockchain.startDifficulty.difficulty

    #Create the new difficulty.
    result = newDifficultyObj(
        last.endHeight,
        last.endHeight + blocksPerPeriod,
        difficultyHash
    )
