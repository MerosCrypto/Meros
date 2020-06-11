from typing import Dict, List, IO, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
main: Blockchain = Blockchain.fromJSON(blocks)

#Only add the first 15 blank Blocks to the alt chain.
alt: Blockchain = Blockchain()
for b in range(15):
  alt.add(Block.fromJSON(blocks[b]))

#Generate an alternative fifteen Blocks.
for i in range(15):
  #Create the next Block.
  block = Block(
    BlockHeader(
      0,
      alt.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      alt.blocks[-1].header.time + 1201 #Use a slightly different time to ensure a different hash.
    ),
    BlockBody()
  )
  block.mine(privKey, alt.difficulty())
  alt.add(block)
  print("Generated Longer Chain, More Work Block " + str(i) + ".")

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/LongerChainMoreWork.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
