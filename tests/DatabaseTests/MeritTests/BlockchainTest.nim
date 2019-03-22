#Blockchain Test.

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

#VerifierIndex object.
import ../../../src/Database/Merit/objects/VerifierIndexObj

#Miners object.
import ../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, and Blockchain libs.
import ../../../src/Database/Merit/Difficulty as DifficultyFile
import ../../../src/Database/Merit/Block
import ../../../src/Database/Merit/Blockchain

#Serialize libs.
import ../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../src/Network/Serialize/Merit/SerializeBlock

#Merit Testing functions.
import TestMerit

#Finals lib.
import finals

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()
    #Blockchain.
    blockchain: Blockchain = newTestBlockchain(
        db,
        "BLOCKCHAIN_TEST",
        30,
        "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA".toBN(16)
    )
    #Current difficulty.
    difficulty: Difficulty
    #Block we're mining.
    mining: Block

#Mine 10 blocks.
for i in 1 .. 10:
    echo "Mining Block " & $i & "."

    #Grab the Difficulty.
    var diffCopy: BN = blockchain.difficulty.difficulty

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
    while not difficulty.verifyDifficulty(mining):
        inc(mining)

    #Add it.
    try:
        if not blockchain.processBlock(mining):
            raise newException(Exception, "")
    except:
        raise newException(ValueError, "Valid Block wasn't successfully added.")

    #Verify it was added to the DB properly.
    if db.get("merit_tip") != mining.header.hash.toString():
        raise newException(ValueError, "Tip wasn't updated in the database.")
    if db.get("merit_" & mining.header.hash.toString()) != mining.serialize():
        raise newException(ValueError, "Block wasn't added to the database.")

    #Verify the Difficulty was updated and is valid.
    if difficulty.start == blockchain.difficulty.start:
        raise newException(ValueError, "The Difficulty's start wasn't updated.")
    if difficulty.endBlock == blockchain.difficulty.endBlock:
        raise newException(ValueError, "The Difficulty's end wasn't updated.")
    if difficulty.difficulty == blockchain.difficulty.difficulty:
        raise newException(ValueError, "The Difficulty's difficulty wasn't updated.")
    if blockchain.difficulty.start != difficulty.endBlock:
        raise newException(ValueError, "The Difficulty isn't valid.")

    #Verify the Difficulty was saved to the DB.
    if db.get("merit_difficulty") != blockchain.difficulty.serialize():
        raise newException(ValueError, "Difficulty wasn't properly saved to the DB.")

echo "Finished the Database/Merit/Blockchain test."
