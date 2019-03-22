#Merit Testing Functions.

#Util lib,
import ../../../src/lib/Util

#BN lib.
import BN

#BLS lib,
import ../../../src/lib/BLS

#Hash lib.
import ../../../src/lib/Hash

#Merit lib.
import ../../../src/Database/Merit/Merit

#Serialize libs.
import ../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../src/Network/Serialize/Merit/SerializeBlock

#Test Database lib.
import ../TestDatabase
export TestDatabase

#Creates a Block, with every setting optional.
proc newTestBlock*(
    nonce: int = 0,
    last: ArgonHash = "".pad(64).toArgonHash(),
    aggregate: BLSSignature = nil,
    indexes: seq[VerifierIndex] = @[],
    miners: Miners = @[
        newMinerObj(
            newBLSPrivateKeyFromSeed("TEST").getPublicKey(),
            uint(100)
        )
    ],
    time: uint = getTime(),
    proof: uint = 0
): Block =
    newBlockObj(
        uint(nonce),
        last,
        aggregate,
        indexes,
        miners,
        time,
        proof
    )

#Creates a Blockchain and genesis Block.
proc newTestBlockchain*(
    db: DatabaseFunctionBox,
    genesis: string,
    blockTime: uint,
    startDifficulty: BN
): Blockchain =
    #Create the Blockchain.
    result = newBlockchain(
        db,
        genesis,
        blockTime,
        startDifficulty
    )

    #Create the Genesis Block.
    var genesisBlock: Block = newBlockObj(
        0,
        genesis.pad(64).toArgonHash(),
        nil,
        @[],
        @[],
        getTime(),
        0
    )

    #Save the Genesis data to the database.
    db.put("merit_tip", genesisBlock.header.hash.toString())
    db.put("merit_" & genesisBlock.header.hash.toString(), genesisBlock.serialize())
    db.put("merit_difficulty", result.difficulty.serialize())

    #Load the Genesis Block onto the Blockchain.
    result.setHeight(1)
    result.load(genesisBlock.header)
    result.load(genesisBlock)
