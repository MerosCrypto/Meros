#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey

#Merit classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Miner Private Key.
privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

#Blockchains.
bbFile: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
main: Blockchain = Blockchain.fromJSON(blocks)
#Only add the first 15 to the alt chain.
alt: Blockchain = Blockchain()
for b in range(15):
  alt.add(Block.fromJSON(blocks[b]))

#Generate an alternative fifteen Blocks.
for i in range(1, 15):
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

  #Mine the Block.
  block.mine(privKey, alt.difficulty())

  #Add it locally.
  alt.add(block)
  print("Generated Longer Chain, More Work Block " + str(i) + ".")

vectors: IO[Any] = open("PythonTests/Vectors/Merit/Reorganizations/LongerChainMoreWork.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
