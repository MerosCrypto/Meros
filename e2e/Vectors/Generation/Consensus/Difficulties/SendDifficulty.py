from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
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

#Create two SendDifficulties which are different.
sendDiffs: List[SignedSendDifficulty] = [
  SignedSendDifficulty(5, 0),
  SignedSendDifficulty(1, 1)
]
for sendDiff in sendDiffs:
  sendDiff.sign(0, blsPrivKey)

#Generate a Block containing the first SendDifficulty.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [sendDiffs[0]]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [sendDiffs[0]], sendDiffs[0].signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

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
  print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Generate a Block containing the new SendDifficulty.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [sendDiffs[1]]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [sendDiffs[1]], sendDiffs[1].signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Create a MeritRemoval by reusing a nonce.
competing: SignedSendDifficulty = SignedSendDifficulty(0, 1)
competing.sign(0, blsPrivKey)
mr: PartialMeritRemoval = PartialMeritRemoval(sendDiffs[1], competing)

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
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

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
  print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/Difficulties/SendDifficulty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
