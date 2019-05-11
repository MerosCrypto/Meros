#State Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Miners object.
import ../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, Blockchain, and State libs.
import ../../../src/Database/Merit/Difficulty
import ../../../src/Database/Merit/Block
import ../../../src/Database/Merit/Blockchain
import ../../../src/Database/Merit/State as StateFile

#Merit Testing functions.
import TestMerit

#Finals lib.
import finals

#Tables standard lib.
import tables

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()
    #Blockchain.
    blockchain: Blockchain = newBlockchain(
        db,
        "STATE_TEST",
        30,
        "".pad(48).toHash(384)
    )
    #Current State.
    current: State = newState(
        db,
        5
    )
    #States.
    states: seq[State] = newSeq[State](10)
    #Miners we're mining to.
    miners: seq[Miners] = @[]
    #Table of wo has how much Merit.
    balances: OrderedTable[string, int] = initOrderedTable[string, int]()
    #Block we're mining.
    mining: Block

#Compare two different States.
proc test(
    original: var State,
    reloaded: var State
) =
    #Check the fields.
    assert(original.deadBlocks == reloaded.deadBlocks)
    assert(original.live == reloaded.live)
    assert(original.processedBlocks == reloaded.processedBlocks)

    #Check the balances.
    for k in balances.keys():
        assert(original[k] == reloaded[k])

echo "Testing State processing and DB interactions."

#Mine 10 blocks.
for i in 1 .. 10:
    echo "Mining Block " & $i & "."

    #Create a list of miners.
    miners.add(newMinersObj(@[]))
    for m in 0 ..< i:
        var
            #Create a key based off their number.
            key: BLSPublicKey = newBLSPrivateKeyFromSeed($char(m)).getPublicKey()
            #Give equal amounts to each miner
            amount: int = 100 div i

        #If this is the first miner, give them the remainder.
        if m == 0:
            amount += 100 mod i

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
    while not blockchain.difficulty.verify(mining.header.hash):
        inc(mining)

    #Add it to the Blockchain.
    try:
        blockchain.processBlock(mining)
    except ValueError as e:
        raise newException(ValueError, "Valid Block wasn't successfully added: " & e.msg)

    #Add it to the State.
    current.processBlock(blockchain, mining)

    #If we're past 5 blocks...
    if i > 5:
        #Iterate over every miner which got paid out back then.
        for m in 0 ..< i - 5:
            #Recreate their key.
            var key: BLSPublicKey = newBLSPrivateKeyFromSeed($char(m)).getPublicKey()
            #Subtract the old Merit payouts.
            balances[key.toString()] -= miners[i - 6].miners[m].amount

    #Reload and test the State.
    states[i - 1] = newState(db, 5)
    test(current, states[i - 1])

    #Check the amount of Merit in existence.
    assert(current.live == min(i, 5) * 100)
    assert(db.get("state_live").fromBinary() == min(i, 5) * 100)

    #Checked the processed blocks tally.
    assert(current.processedBlocks == blockchain.height)
    assert(db.get("state_processed").fromBinary() == blockchain.height)

    #Check the balances.
    var holdersStr: string = ""
    for k in balances.keys():
        holdersStr &= k
        assert(current[k] == balances[k])
        assert(db.get("state_" & k).fromBinary() == balances[k])

    #Check the holders string.
    assert(holdersStr == db.get("state_holders"))

#Test reversions.
for i in 1 .. 10:
    echo "Reverting State " & $i & "."
    var copy: State = current
    copy.revert(blockchain, states[i - 1].processedBlocks)
    test(copy, states[i - 1])

#Test catch ups.
for i in 1 .. 10:
    echo "Catching Up State " & $i & "."
    states[i - 1].catchup(blockchain)
    test(states[i - 1], current)

echo "Finished the Database/Merit/State Test."
