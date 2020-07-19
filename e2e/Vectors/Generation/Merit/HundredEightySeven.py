from typing import IO, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

blockchain: Blockchain = Blockchain()

for b in range(1, 3):
  block: Block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      privKey.toPublicKey().serialize(),
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(privKey, blockchain.difficulty())
  blockchain.add(block)

vectors: IO[Any] = open("e2e/Vectors/Merit/HundredEightySeven.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
