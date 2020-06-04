#Types.
from typing import Dict, List, IO, Any

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

#Miner Private Key.
privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

#Blockchains.
bbFile: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
main: Blockchain = Blockchain.fromJSON(blocks)
#Only add the first 15 to the alt chain.
alt: Blockchain = Blockchain()
for b in range(15):
  alt.add(Block.fromJSON(blocks[b]))

#Generate an alternative five Blocks.
for i in range(1, 5):
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
      alt.blocks[-1].header.time + 1 #Use a much shorter time to acquire more work.
    ),
    BlockBody()
  )

  #Mine the Block.
  block.mine(privKey, alt.difficulty())

  #Add it locally.
  alt.add(block)
  print("Generated Shorter Chain, More Work Block " + str(i) + ".")

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/ShorterChainMoreWork.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
