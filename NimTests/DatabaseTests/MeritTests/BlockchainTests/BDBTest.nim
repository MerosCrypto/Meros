#Blockchain DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash and Merkle libs.
import ../../../../src/lib/Hash
import ../../../../src/lib/Merkle

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Element lib.
import ../../../../src/Database/Consensus/Elements/Element

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
        #Starting Difficultty.
        startDifficulty: Hash[384] = "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA".toHash(384)
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "BLOCKCHAIN_TEST",
            30,
            startDifficulty
        )
        #State. This is needed for the Blockchain's nickname table.
        state: State = newState(
            db,
            10,
            1
        )

        #Transaction hash.
        hash: Hash[384]
        #Transactions.
        transactions: seq[Hash[384]]
        #Elements.
        elements: seq[BlockElement]
        #Verifiers hash.
        verifiers: Hash[384]
        #Miners.
        miners: seq[MinerWallet]
        #Selected miner for the next Block.
        miner: int
        #Block.
        mining: Block

    #Compare the Blockchain against the reloaded Blockchain.
    proc compare() =
        #Reload the Blockchain.
        var reloaded: Blockchain = newBlockchain(
            db,
            "BLOCKCHAIN_TEST",
            30,
            startDifficulty
        )

        #Compare the Blockchains.
        compare(blockchain, reloaded)

    #Iterate over 20 'rounds'.
    for _ in 1 .. 20:
        #Randomize the Transactions.
        transactions = @[]
        for _ in 0 ..< rand(300):
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))
            transactions.add(hash)

        #Randomize the Elements.

        #Create a random verifiers hash.
        for b in 0 ..< 48:
            verifiers.data[b] = uint8(rand(255))

        #Decide if this is a nickname or new miner Block.
        if (miners.len == 0) or (rand(2) == 0):
            #New miner.
            miner = miners.len
            miners.add(newMinerWallet())

            #Create the Block with the new miner.
            mining = newBlankBlock(
                uint32(0),
                blockchain.tip.header.hash,
                verifiers,
                miners[miner],
                transactions,
                elements
            )
        else:
            #Grab a random miner.
            miner = rand(high(miners))

            #Create the Block with the existing miner.
            mining = newBlankBlock(
                uint32(0),
                blockchain.tip.header.hash,
                verifiers,
                uint16(miner),
                miners[miner],
                transactions,
                elements
            )

        #Mine it.
        while blockchain.difficulty.difficulty > mining.header.hash:
            miners[miner].hash(mining.header, mining.header.proof + 1)

        #Add it to the Blockchain and State.
        blockchain.processBlock(mining)
        state.processBlock(blockchain)

        #Commit the DB.
        db.commit(blockchain.height)

        #Compare the Blockchains.
        compare()

    echo "Finished the Database/Merit/Blockchain/DB Test."
