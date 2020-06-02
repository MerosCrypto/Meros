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
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(3, 0),
  SignedDataDifficulty(1, 1)
]
for dataDiff in dataDiffs:
  dataDiff.sign(0, blsPrivKey)

#Generate a Block containing the DataDifficulty.
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
  block.mine(blsPrivKey, blockchain.difficulty())
  blockchain.add(block)
  print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Now that we have aa vote, update our vote.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [dataDiffs[1]]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [dataDiffs[1]], dataDiffs[1].signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Create MeritRemovals by reusing nonces.
for n in range(2):
  competing: SignedDataDifficulty = SignedDataDifficulty(0, n)
  competing.sign(0, blsPrivKey)
  mr: PartialMeritRemoval = PartialMeritRemoval(dataDiffs[n], competing)
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
  block.mine(blsPrivKey, blockchain.difficulty())
  blockchain.add(block)
  print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Mine another 50 Blocks.
for _ in range(50):
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
  block.mine(blsPrivKey, blockchain.difficulty())
  blockchain.add(block)
  print("Generated DataDifficulty Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/Difficulties/DataDifficulty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
