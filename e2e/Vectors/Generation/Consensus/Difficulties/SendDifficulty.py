#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#SendDifficulty and MeritRemoval classes.
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval

#Blockchain classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain: Blockchain = Blockchain.fromJSON(blocks)
bbFile.close()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create a SendDifficulty.
sendDiff: SignedSendDifficulty = SignedSendDifficulty(5, 0)
sendDiff.sign(0, blsPrivKey)

#Generate a Block containing the SendDifficulty.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [sendDiff]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [sendDiff], sendDiff.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
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
  #Mine it.
  block.mine(blsPrivKey, blockchain.difficulty())

  #Add it.
  blockchain.add(block)
  print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Now that we have aa vote, update our vote.
sendDiff = SignedSendDifficulty(1, 1)
sendDiff.sign(0, blsPrivKey)

#Generate a Block containing the new SendDifficulty.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [sendDiff]),
    1,
    bytes(4),
    bytes(32),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [sendDiff], sendDiff.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated SendDifficulty Block " + str(len(blockchain.blocks)) + ".")

#Create a MeritRemoval by reusing a nonce.
competing: SignedSendDifficulty = SignedSendDifficulty(0, 1)
competing.sign(0, blsPrivKey)
mr: PartialMeritRemoval = PartialMeritRemoval(sendDiff, competing)

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
