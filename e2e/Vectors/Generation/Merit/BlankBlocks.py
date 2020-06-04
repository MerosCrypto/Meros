#Types.
from typing import IO, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey

#Merit classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
blockchain: Blockchain = Blockchain()

#Miner Private Key.
privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

#Create the Block.
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

#Generate Blocks.
for i in range(1, 26):
  #Mine the Block.
  block.mine(privKey, blockchain.difficulty())

  #Add it locally.
  blockchain.add(block)
  print("Generated Blank Block " + str(i) + ".")

  #Create the next Block.
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

vectors: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "w")
vectors.write(json.dumps(blockchain.toJSON()))
vectors.close()
