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

import strutils

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
        raise newException(ValueError, "Valid Block wasn't successfully added. " & getCurrentExceptionMsg())

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
    if state.live != uint(min(i, 5) * 100):
        raise newException(ValueError, "State has the wrong amount of live Merit.")
    if db.get("merit_live").fromBinary() != min(i, 5) * 100:
        raise newException(ValueError, "DB has the wrong amount of live Merit.")

    #Check the balances.
    var holdersStr: string = ""
    for k in balances.keys():
        holdersStr &= k
        if state[k] != balances[k]:
            raise newException(ValueError, "Our balance table and the State disagree.")
        if uint(db.get("merit_" & k).fromBinary()) != balances[k]:
            raise newException(ValueError, "Our balance table and the DB disagree.")

    #Check the holders string.
    if holdersStr != state.holdersStr:
        raise newException(ValueError, "Our holdersStr and the State disagree.")
    if holdersStr != db.get("merit_holders"):
        raise newException(ValueError, "Our holdersStr and the DB disagree.")

#Reload the State.
state = newState(db, 5)
#Check the live Merit.
if state.live != 500:
    raise newException(ValueError, "Loaded State has the wrong amount of live Merit.")

#Check the balances.
var holdersStr: string = ""
for k in balances.keys():
    holdersStr &= k
    if state[k] != balances[k]:
        raise newException(ValueError, "Our balance table and the loaded State disagree.")

#Check the holders string.
if state.holdersStr != holdersStr:
    raise newException(ValueError, "Our holdersStr and the loaded State disagree.")

echo "Finished the Database/Merit/State test."
