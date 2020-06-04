#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#Element classes.
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval, SignedMeritRemoval

#Blockchain classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Blockchains.
blockchain: Blockchain = Blockchain()

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
print("Generated Hundred Twenty Three Partial Block " + str(len(blockchain.blocks)) + ".")

#Create conflicting Data Difficulties.
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(3, 0),
  SignedDataDifficulty(4, 0)
]
dataDiffs[0].sign(0, blsPrivKey)
dataDiffs[1].sign(0, blsPrivKey)

#Generate a Block containing the first Data Difficulty.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [dataDiffs[0]]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [dataDiffs[0]], dataDiffs[0].signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Twenty Three Partial Block " + str(len(blockchain.blocks)) + ".")

#Create a partial MeritRemoval out of the conflicting Data Difficulties.
partial: PartialMeritRemoval = PartialMeritRemoval(dataDiffs[0], dataDiffs[1])

#Generate a Block containing the partial MeritRemoval.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [partial]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [partial], partial.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Twenty Three Partial Block " + str(len(blockchain.blocks)) + ".")

#Create a MeritRemoval which isn't partial.
mr: SignedMeritRemoval = SignedMeritRemoval(dataDiffs[0], dataDiffs[1])

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
print("Generated Hundred Twenty Three Partial Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Partial.json", "w")
vectors.write(json.dumps(result))
vectors.close()
