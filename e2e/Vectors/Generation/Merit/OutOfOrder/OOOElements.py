from typing import IO, Dict, List, Any

from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

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

#Mine 24 more Blocks so a vote is earned on the Block after this.
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

#Now that we have a vote, submit a Block which has two DataDifficulty updates in the same Block.
#The first Element should have a higher nonce than the second.
#This will verify Meros properly handles out-of-order Elements included in a Block.
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(1, 1),
  SignedDataDifficulty(2, 0)
]
for dataDiff in dataDiffs:
  dataDiff.sign(0, blsPrivKey)

for _ in range(2):
  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      #Used so the type checkers realize List[SignedDataDifficulty] is a viable List[Element].
      #pylint: disable=unnecessary-comprehension
      BlockHeader.createContents([], [e for e in dataDiffs]),
      1,
      bytes(4),
      bytes(32),
      0,
      blockchain.blocks[-1].header.time + 1200
    ),
    #pylint: disable=unnecessary-comprehension
    BlockBody([], [e for e in dataDiffs], Signature.aggregate([d.signature for d in dataDiffs]))
  )
  block.mine(blsPrivKey, blockchain.difficulty())
  blockchain.add(block)

  #To verify the nonce isn't improperly set, add one more Data Difficulty with a nonce of 2.
  dataDiffs = [SignedDataDifficulty(4, 2)]
  dataDiffs[0].sign(0, blsPrivKey)

vectors: IO[Any] = open("e2e/Vectors/Merit/OutOfOrder/Elements.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
