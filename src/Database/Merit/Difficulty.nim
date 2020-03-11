#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Blockchain object.
import objects/BlockchainObj

#Math and Algorithm standard libs.
import math
import algorithm

#Calculate the next difficulty.
proc calculateNextDifficulty*(
    blockchain: Blockchain
): uint64 {.forceCheck: [].} =
    if blockchain.height < 6:
        return blockchain.difficulties[0]

    var
        #Window length.
        windowLength: int
        #Difficulties.
        difficulties: seq[uint64]
        #Median difficulty.
        median: uint64
        #Elapsed time.
        time: uint64

    #If we're in the first month, the window length is 5 Blocks (just under 1 hour).
    if blockchain.height < 4320:
        windowLength = 5
    #If we're in the first three months, the window length is 9 Blocks (1.5 hours).
    elif blockchain.height < 12960:
        windowLength = 9
    #If we're in the first six months, the window length is 18 Blocks (3 hours).
    elif blockchain.height < 25920:
        windowLength = 18
    #If we're in the first year, the window length is 36 Blocks (6 hours).
    elif blockchain.height < 52560:
        windowLength = 36
    #Else, if it's over an year, the window length is 72 Blocks (12 hours).
    else:
        windowLength = 72

    #Grab the difficulties.
    #We exclude the first difficulty as its PoW was created before the indicated time.
    difficulties = blockchain.difficulties[blockchain.difficulties.len - (windowLength - 1) ..< blockchain.difficulties.len]

    #Sort the difficulties.
    difficulties.sort()
    #Grab the meddian difficulty.
    median = difficulties[windowLength div 2]
    #Remove outlying difficulties.
    for _ in 0 ..< windowLength div 10:
        if (difficulties[^1] - median) > (median - difficulties[0]):
            difficulties.del(high(difficulties))
        else:
            difficulties.delete(0)

    #Calculate the time.
    try:
        time = uint64(blockchain.tail.header.time - blockchain[blockchain.height - windowLength].header.time)
    except IndexError:
        panic("Couldn't get Block " & $(blockchain.height - windowLength) & " when the height is " & $blockchain.height & ".")

    #Calculate the new difficulty.
    result = max(sum(difficulties) * uint64(blockchain.blockTime) div time, 1)
