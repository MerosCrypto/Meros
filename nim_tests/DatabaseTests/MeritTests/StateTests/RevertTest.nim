#State Revert Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

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
        #States.
        states: seq[State] = @[]
        #List of MeritHolders.
        holders: seq[MinerWallet] = @[]
        #List of MeritHolders used to grab a miner from.
        potentials: seq[MinerWallet] = @[]
        #List of MeritHolders with Merit.
        merited: seq[BLSPublicKey] = @[]
        #MeritHolder to remove Merit from.
        toRemove: int
        #Miners we're mining to.
        miners: seq[Miner] = @[]
        #Remaining amount of Merit.
        remaining: int
        #Amount to pay the miner.
        amount: int
        #Index of the miner we're choosing.
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
        #Create a random amount of Merit Holders.
        for _ in 0 ..< rand(5) + 2:
            holders.add(newMinerWallet())

        #Randomize the miners.
        potentials = holders
        miners = newSeq[Miner](rand(holders.len - 2) + 1)
        remaining = 100
        for m in 0 ..< miners.len:
            #Set the amount to pay the miner.
            amount = rand(remaining - 1) + 1
            #Make sure everyone gets at least 1 and we don't go over 100.
            if (remaining - amount) < (miners.len - m):
                amount = 1
            #But if this is the last account...
            if m == miners.len - 1:
                amount = remaining

            #Subtract the amount from remaining.
            remaining -= amount

            #Set the Miner.
            miner = rand(potentials.len - 1)
            miners[m] = newMinerObj(
                potentials[miner].publicKey,
                amount
            )
            merited.add(potentials[miner].publicKey)
            potentials.del(miner)

        #Create the Block.
        mining = newBlankBlock(
            nonce = blockchain.height,
            last = blockchain.tip.header.hash,
            miners = newMinersObj(miners)
        )
        #Mine it.
        while not blockchain.difficulty.verify(mining.header.hash):
            inc(mining)

        #Add it to the Blockchain.
        blockchain.processBlock(mining)

        #Add it to the State.
        states[^1].processBlock(blockchain, mining)

        #Remove Merit from a random MeritHolder who has Merit.
        toRemove = rand(merited.len - 1)
        states[^1].remove(merited[toRemove], mining)
        merited.del(toRemove)

        #Commit the DB.
        db.commit(mining.nonce)

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
