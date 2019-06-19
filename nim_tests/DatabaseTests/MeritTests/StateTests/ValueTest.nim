#State Value Test.

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

#Tables standard lib.
import tables

#Random standard lib.
import random

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
    state: State = newState(db, 5, blockchain.height)
    #Table of wo has how much Merit.
    balances: OrderedTable[string, int] = initOrderedTable[string, int]()
    #List of MeritHolders.
    holders: seq[MinerWallet] = @[]
    #List of MeritHolders used to grab a miner from.
    potentials: seq[MinerWallet]
    #Miners we're mining to.
    miners: seq[Miner]
    #Remaining amount of Merit.
    remaining: int
    #Amount to pay the miner.
    amount: int
    #Index of the miner we're choosing.
    miner: int
    #Block we're mining.
    mining: Block
    #Key of the miner we're updating the balance of.
    key: string

#Iterate over 20 'rounds'.
for i in 1 .. 20:
    #Create a random amount of Merit Holders.
    for _ in 0 ..<  rand(5) + 2:
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
        potentials.del(miner)

    #Create the Block.
    mining = newBlankBlock(
        nonce = i,
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

    #Update the Merit balances of everyone on our end.
    for minedMiner in blockchain.tip.miners.miners:
        key = minedMiner.miner.toString()
        if not balances.hasKey(key):
            balances[key] = 0
        #Add the new Merit.
        balances[key] += minedMiner.amount

    if blockchain.height > 5:
        for minedMiner in blockchain[blockchain.tip.nonce - 5].miners.miners:
            key = minedMiner.miner.toString()
            #Subtract the old Merit.
            balances[key] -= minedMiner.amount

    #Check the balances.
    for k in balances.keys():
        assert(state[k] == balances[k])

echo "Finished the Database/Merit/State/Value Test."
