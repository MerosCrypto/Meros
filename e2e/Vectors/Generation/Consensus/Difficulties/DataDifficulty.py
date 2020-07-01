from typing import IO, Dict, List, Any

from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain: Blockchain = Blockchain.fromJSON(blocks)
bbFile.close()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create two DataDifficulties which are different.
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(3, 0),
  SignedDataDifficulty(1, 1)
]
for dataDiff in dataDiffs:
  dataDiff.sign(0, blsPrivKey)

#Generate a Block containing the first DataDifficulty.
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
block.mine(blsPrivKey, blockchain.difficulty())
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

#Now that we have a vote, update our vote.
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

proto.add(elements=[MeritRemoval(DataDifficulty(1, 1, 0), DataDifficulty(2, 1, 0), True)])

for _ in range(50):
  proto.add()

vectors: IO[Any] = open("e2e/Vectors/Consensus/Difficulties/DataDifficulty.json", "w")
vectors.write(json.dumps({
  "blockchain": proto.toJSON()
}))
vectors.close()
