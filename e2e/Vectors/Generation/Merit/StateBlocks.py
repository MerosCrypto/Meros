from typing import List, IO, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

blockchain: Blockchain = Blockchain()

privKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest()),
  PrivateKey(blake2b(b'\2', digest_size=32).digest()),
  PrivateKey(blake2b(b'\3', digest_size=32).digest()),
  PrivateKey(blake2b(b'\4', digest_size=32).digest())
]

#Assign every Miner Merit.
for i in range(6):
  block: Block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      privKeys[i].toPublicKey().serialize(),
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(privKeys[i], blockchain.difficulty())
  blockchain.add(block)
  print("Generated State Block " + str(i) + ".")

#Assign Miner 0 4 more Blocks of Merit.
for i in range(6, 10):
  block: Block = Block(
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
  block.mine(privKeys[0], blockchain.difficulty())
  blockchain.add(block)
  print("Generated State Block " + str(i) + ".")

vectors: IO[Any] = open("e2e/Vectors/Merit/StateBlocks.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
