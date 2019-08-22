#Blockchain DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, and Blockchain libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain

#Merit Testing lib.
import ../TestMerit

#Compare Merit lib.
import ../CompareMerit

#StInt lib..
import StInt

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

        #Records.
        records: seq[MeritHolderRecord]
        #Hash for the Record's 'merkle'.
        hash: Hash[384]

        #Amount of records/amount to pay a miner.
        amount: int

        #Miners.
        miners: seq[Miner]
        #Remaining amount of Merit.
        remaining: int

        #Block we're mining.
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
        #Randomize the records.
        records = @[]
        amount = rand(300)
        for _ in 0 ..< amount:
            for b in 0 ..< 48:
                hash.data[b] = uint8(rand(255))

            #Add the record.
            records.add(
                newMeritHolderRecord(
                    newMinerWallet().publicKey,
                    rand(high(int32)),
                    hash
                )
            )

        #Randomize the miners.
        miners = newSeq[Miner](rand(99) + 1)
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

            #Set the Miner.
            miners[m] = newMinerObj(
                newMinerWallet().publicKey,
                amount
            )

            #Subtract the amount from remaining.
            remaining -= amount

        #Create the Block.
        mining = newBlankBlock(
            blockchain.height,
            blockchain.tip.header.hash,
            newMinerWallet().sign(rand(high(int32)).toBinary()),
            records,
            newMinersObj(miners)
        )

        #Mine it.
        while not blockchain.difficulty.verify(mining.header.hash):
            inc(mining)

        #Add it.
        blockchain.processBlock(mining)

        #Commit the DB.
        db.commit(mining.nonce)

        #Compare the Blockchains.
        compare()

    echo "Finished the Database/Merit/Blockchain/DB Test."
