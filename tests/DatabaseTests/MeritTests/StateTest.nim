#State Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#Numerical libs.
import BN
import ../../../src/lib/Base

#BLS lib.
import ../../../src/lib/BLS

#VerifierIndex and Miners object.
import ../../../src/Database/Merit/objects/VerifierIndexObj
import ../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, Blockchain, and State libs.
import ../../../src/Database/Merit/Difficulty
import ../../../src/Database/Merit/Block
import ../../../src/Database/Merit/Blockchain
import ../../../src/Database/Merit/State

#Merit Testing functions.
import TestMerit

#Tables standard lib.
import tables

#Finals lib.
import finals

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()
    #Blockchain.
    blockchain: Blockchain = newBlockchain(
        db,
        "STATE_TEST",
        30,
        newBN()
    )
    #State.
    state: State = newState(
        db,
        5
    )
    #Miners we're mining to.
    miners: seq[Miners] = @[]
    #Table of wo has how much Merit.
    balances: OrderedTable[string, uint] = initOrderedTable[string, uint]()
    #Block we're mining.
    mining: Block

echo "Testing State processing and DB interactions."

#Mine 10 blocks.
for i in 1 .. 10:
    echo "Mining Block " & $i & "."

    #Create a list of miners.
    miners.add(@[])
    for m in 0 ..< i:
        var
            #Create a key based off their number.
            key: BLSPublicKey = newBLSPrivateKeyFromSeed($char(m)).getPublicKey()
            #Give equal amounts to each miner
            amount: uint = uint(100 div i)

        #If this is the first miner, give them the remainder.
        if m == 0:
            amount += uint(100 mod i)

        #Add the miner.
        miners[^1].add(
            newMinerObj(
                key,
                amount
            )
        )

        #Make sure they have a balance.
        if not balances.hasKey(key.toString()):
            balances[key.toString()] = 0
        #Update their balance.
        balances[key.toString()] += amount

    #Create the Block.
    mining = newTestBlock(
        nonce = i,
        last = blockchain.tip.header.hash,
        miners = miners[^1]
    )

    #Mine it.
    while not blockchain.difficulty.verifyDifficulty(mining):
        inc(mining)

    #Add it to the Blockchain.
    try:
        if not blockchain.processBlock(mining):
            raise newException(Exception, "")
    except:
        raise newException(ValueError, "Valid Block wasn't successfully added.")

    #Add it to the State.
    state.processBlock(blockchain, mining)

    #If we're past 5 blocks...
    if i > 5:
        #Iterate over every miner which got paid out back then.
        for m in 0 ..< i - 5:
            #Recreate their key.
            var key: BLSPublicKey = newBLSPrivateKeyFromSeed($char(m)).getPublicKey()
            #Subtract the old Merit payouts.
            balances[key.toString()] -= miners[i - 6][m].amount

    #Check the amount of Merit in existence.
    assert(state.live == uint(min(i, 5) * 100))
    assert(db.get("merit_live").fromBinary() == min(i, 5) * 100)

    #Check the balances.
    var holdersStr: string = ""
    for k in balances.keys():
        holdersStr &= k
        assert(state[k] == balances[k])
        assert(uint(db.get("merit_" & k).fromBinary()) == balances[k])

    #Check the holders string.
    assert(holdersStr == state.holdersStr)
    assert(holdersStr == db.get("merit_holders"))

#Reload the State.
state = newState(db, 5)
#Check the live Merit.
assert(state.live == 500)

#Check the balances.
var holdersStr: string = ""
for k in balances.keys():
    holdersStr &= k
    assert(state[k] == balances[k])

#Check the holders string.
assert(state.holdersStr == holdersStr)

echo "Finished the Database/Merit/State Test."
