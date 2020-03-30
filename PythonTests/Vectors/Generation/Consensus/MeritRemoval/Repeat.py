#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey

#Element classes.
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
blockchain: Blockchain = Blockchain()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Generate a Block granting the holder Merit.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        bytes(32),
        1,
        bytes(4),
        bytes(32),
        blsPubKey.serialize(),
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Repeat Block " + str(len(blockchain.blocks)) + ".")

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(3, 0)
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
print("Generated Repeat Block " + str(len(blockchain.blocks)) + ".")

#Create a conflicting DataDifficulty with the same nonce.
dataDiffConflicting = SignedDataDifficulty(1, 0)
dataDiffConflicting.sign(0, blsPrivKey)

#Create a MeritRemoval out of the two of them.
mr: PartialMeritRemoval = PartialMeritRemoval(dataDiff, dataDiffConflicting)

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
print("Generated Repeat Block " + str(len(blockchain.blocks)) + ".")

#Generate another Block containing the MeritRemoval.
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
print("Generated Repeat Block " + str(len(blockchain.blocks)) + ".")

result: List[Dict[str, Any]] = blockchain.toJSON()
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Repeat.json", "w")
vectors.write(json.dumps(result))
vectors.close()
