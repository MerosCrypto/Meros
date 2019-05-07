#Blockchain Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#VerifierRecord object.
import ../../../src/Database/common/objects/VerifierRecordObj

#Miners object.
import ../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, and Blockchain libs.
import ../../../src/Database/Merit/Difficulty
import ../../../src/Database/Merit/Block
import ../../../src/Database/Merit/Blockchain

#Serialize libs.
import ../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../src/Network/Serialize/Merit/SerializeBlock

#Merit Testing functions.
import TestMerit

#Finals lib.
import finals

#StInt lib..
import StInt

#String utils standard lib (for toUpper).
import strutils

proc test*(blocks: int) =
    echo "Testing Blockchain mining and DB interactions with " & $blocks & " blocks (plus genesis)."

    var
        #Database.
        db: DatabaseFunctionBox = newTestDatabase()
        #Starting Difficultty.
        startDifficulty: Hash[384] = "11AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA".toHash(384)
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "BLOCKCHAIN_TEST",
            30,
            startDifficulty
        )
        #Current difficulty.
        difficulty: Difficulty
        #Block we're mining.
        mining: Block

    #Mine blocks blocks.
    for i in 1 .. blocks:
        echo "Mining Block " & $i & "."

        #Grab the Difficulty.
        var diffCopy: StUint[512] = blockchain.difficulty.difficulty

        difficulty = newDifficultyObj(
            blockchain.difficulty.start,
            blockchain.difficulty.endBlock,
            diffCopy
        )

        #Create the Block.
        mining = newTestBlock(
            i,
            blockchain.tip.header.hash
        )

        #Mine it.
        while not difficulty.verify(mining.header.hash):
            inc(mining)

        #Add it.
        try:
            blockchain.processBlock(mining)
        except ValueError as e:
            raise newException(ValueError, "Valid Block wasn't successfully added: " & e.msg)

        #Verify it was added to the DB properly.
        assert(db.get("merit_tip") == mining.header.hash.toString())
        assert(db.get("merit_" & mining.header.hash.toString()) == mining.serialize())

        #Verify the Start Difficulty is the same.
        assert(blockchain.startDifficulty.difficulty.toHex().pad(96, '0').toUpper() == $startDifficulty)
        assert(blockchain.startDifficulty.start == 0)
        assert(blockchain.startDifficulty.endBlock == 1)

        #Verify the Difficulty was updated and is valid.
        assert(difficulty.start != blockchain.difficulty.start)
        assert(difficulty.endBlock != blockchain.difficulty.endBlock)
        #If this is the first difficulty, the difficulty will be the same.
        #The genesis block has a time of 0 which means we went way over the block time and should lower the difficulty.
        #However, the starting difficulty is the minimum difficulty.
        if i == 1:
            assert(difficulty.difficulty == blockchain.difficulty.difficulty)
        else:
            assert(difficulty.difficulty != blockchain.difficulty.difficulty)
        assert(difficulty.endBlock + 1 == blockchain.difficulty.start)

        #Verify the Difficulty was saved to the DB.
        assert(db.get("merit_difficulty") == blockchain.difficulty.serialize())

    #Reload the Blockchain.
    echo "Reloading the chain..."
    var reloaded: Blockchain = newBlockchain(
        db,
        "BLOCKCHAIN_TEST",
        30,
        startDifficulty
    )

    echo "Testing properties..."

    #Check the block time.
    assert(blockchain.blockTime == reloaded.blockTime)

    #Check the starting difficulty.
    assert(blockchain.startDifficulty.start == reloaded.startDifficulty.start)
    assert(blockchain.startDifficulty.endBlock == reloaded.startDifficulty.endBlock)
    assert(blockchain.startDifficulty.difficulty == reloaded.startDifficulty.difficulty)

    #Check the height.
    assert(blockchain.height == reloaded.height)

    #Check the difficulty.
    assert(blockchain.difficulty.start == reloaded.difficulty.start)
    assert(blockchain.difficulty.endBlock == reloaded.difficulty.endBlock)
    assert(blockchain.difficulty.difficulty == reloaded.difficulty.difficulty)

    #Check the Blocks.
    echo "Testing Blocks..."
    for i in uint(0) .. uint(blocks):
        #If they serialize to the same thing, they're the same, as proven by our SerializeBlock Test.
        assert(blockchain[i].serialize() == reloaded[i].serialize())

test(5)
test(9)
test(15)

echo "Finished the Database/Merit/Blockchain Test."
