#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey

#DataDifficulty and MeritRemoval classes.
from PythonTests.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from PythonTests.Classes.Consensus.MeritRemoval import PartialMeritRemoval

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
bbFile: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain: Blockchain = Blockchain.fromJSON(blocks)
bbFile.close()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(bytes.fromhex("AA" * 32), 0)
dataDiff.sign(0, blsPrivKey)

#Generate a Block containing the DataDifficulty.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([], [dataDiff]),
        1,
        bytes(4),
        bytes(32),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [dataDiff], dataDiff.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Mine 24 more Blocks until there's a vote.
for _ in range(24):
    block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            bytes(32),
            1,
            bytes(4),
            bytes(32),
            0,
            blockchain.blocks[-1].header.time + 1200
        ),
        BlockBody()
    )
    #Mine it.
    block.mine(blsPrivKey, blockchain.difficulty())

    #Add it.
    blockchain.add(block)
    print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Now that we have aa vote, update our vote.
dataDiff = SignedDataDifficulty(bytes.fromhex("8888888888888888888888888888888888888888888888888888888888888888"), 1)
dataDiff.sign(0, blsPrivKey)

#Generate a Block containing the new DataDifficulty.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([], [dataDiff]),
        1,
        bytes(4),
        bytes(32),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [dataDiff], dataDiff.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Create a MeritRemoval by reusing a nonce.
competing: SignedDataDifficulty = SignedDataDifficulty(bytes.fromhex("00" * 32), 1)
competing.sign(0, blsPrivKey)
mr: PartialMeritRemoval = PartialMeritRemoval(dataDiff, competing)

#Generate a Block containing the MeritRemoval.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([], [mr]),
        1,
        bytes(4),
        bytes(32),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [mr], mr.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/Difficulties/DataDifficulty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
