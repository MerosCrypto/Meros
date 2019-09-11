#State DB Test.

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
        #State.
        state: State = newState(db, 30, blockchain.height)

        #Thresholds.
        thresholds: seq[int] = @[]
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

    #Compare the State against the reloaded State.
    proc compare() =
        #Reload the State.
        var reloaded: State = newState(db, 30, blockchain.height)

        #Compare the States.
        compare(state, reloaded)

    #Iterate over 20 'rounds'.
    for r in 1 .. 20:
        #Add the current Node Threshold to thresholds.
        thresholds.add(state.protocolThresholdAt(r))

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
        state.processBlock(blockchain, mining)

        #Remove Merit from a random MeritHolder who has Merit.
        toRemove = rand(merited.len - 1)
        state.remove(merited[toRemove], mining)
        merited.del(toRemove)

        #Commit the DB.
        db.commit(mining.nonce)

        #Compare the States.
        compare()

    #Check that the State hsaved it had 0 Merit at the start.
    assert(state.loadLive(0) == 0)
    #Check the threshold is just plus one.
    assert(state.protocolThresholdAt(0) == 1)

    #Check every existing threshold.
    for t in 0 ..< len(thresholds):
        assert(state.protocolThresholdAt(t) == thresholds[t])

    #Checking loading the Merit for the latest Block returns the State's Merit.
    assert(state.loadLive(21) == state.live)

    #Check future thresholds.
    for t in len(thresholds) + 2 ..< len(thresholds) + 22:
        assert(state.protocolThresholdAt(t) == min(state.live + ((t - 21) * 100), state.deadBlocks * 100) div 2 + 1)

    echo "Finished the Database/Merit/State/DB Test."
