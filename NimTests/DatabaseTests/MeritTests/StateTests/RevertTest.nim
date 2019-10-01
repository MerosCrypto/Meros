#State Revert Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Difficulty, Block, Blockchain, and State libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain
import ../../../../src/Database/Merit/State

#Merit Testing lib.
import ../TestMerit

#Compare Merit lib.
import ../CompareMerit

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #Database.
        db: DB = newTestDatabase()
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "STATE_TEST",
            30,
            "".pad(48).toHash(384)
        )
        #State.
        states: seq[State] = @[]

        #Miners.
        miners: seq[MinerWallet]
        #Selected miner for the next Block.
        miner: int
        #Block we're mining.
        mining: Block

    #Create the initial state.
    states.add(
        newState(
            db,
            5,
            blockchain.height
        )
    )

    #Iterate over 20 'rounds'.
    for _ in 1 .. 20:
        #Decide if this is a nickname or new miner Block.
        if (miners.len == 0) or (rand(2) == 0):
            #New miner.
            miner = miners.len
            miners.add(newMinerWallet())

            #Create the Block with the new miner.
            mining = newBlankBlock(
                last = blockchain.tip.header.hash,
                miner = miners[miner]
            )
        else:
            #Grab a random miner.
            miner = rand(high(miners))

            #Create the Block with the existing miner.
            mining = newBlankBlock(
                last = blockchain.tip.header.hash,
                nick = uint16(miner),
                miner = miners[miner]
            )

        #Mine it.
        while blockchain.difficulty.difficulty > mining.header.hash:
            miners[miner].hash(mining.header, mining.header.proof + 1)

        #Add it to the Blockchain and latest State.
        blockchain.processBlock(mining)
        states[^1].processBlock(blockchain, mining)

        #Commit the DB.
        db.commit(blockchain.height)

        #Copy the State.
        states.add(states[^1])

    #Test reversions.
    var
        copy: State
        reloaded: State
    for s in 1 ..< states.len:
        var revertTo: int = rand(s - 1) + 1
        copy = states[s]
        copy.revert(blockchain, states[revertTo].processedBlocks)
        compare(copy, states[revertTo])

        reloaded = newState(db, 5, blockchain.height)
        compare(states[^1], reloaded)

    #Test chained reversions.
    var revertedAtOnce: State
    for _ in 1 .. 5:
        copy = states[^(rand(3) + 1)]
        copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))
        copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))
        copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))

        revertedAtOnce = states[^1]
        revertedAtOnce.revert(blockchain, copy.processedBlocks)
        compare(copy, revertedAtOnce)

        reloaded = newState(db, 5, blockchain.height)
        compare(states[^1], reloaded)

    echo "Finished the Database/Merit/State/Revert Test."
