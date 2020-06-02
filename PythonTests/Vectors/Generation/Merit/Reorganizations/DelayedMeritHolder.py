#Types.
from typing import List, IO, Any

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

#Blockchains.
main: Blockchain = Blockchain()
alt: Blockchain = Blockchain()

#Miner Private Keys.
privKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]

#Create five Block to the first miner.
block: Block = Block(
  BlockHeader(
    0,
    main.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    privKeys[0].toPublicKey().serialize(),
    main.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
for b in range(5):
  block.mine(privKeys[0], main.difficulty())
  main.add(block)
  alt.add(block)
  print("Generated Reorganizations Delayed Merit Holder Block " + str(b + 1) + ".")

  block = Block(
    BlockHeader(
      0,
      main.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      main.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

#Create the Block to the second miner.
block = Block(
  BlockHeader(
    0,
    main.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    privKeys[1].toPublicKey().serialize(),
    main.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(privKeys[1], alt.difficulty())
main.add(block)
print("Generated Reorganizations Delayed Merit Holder Block 6.")

#Create the competing Block to the first miner.
block = Block(
  BlockHeader(
    0,
    alt.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    0,
    alt.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(privKeys[0], alt.difficulty())
alt.add(block)
print("Generated Reorganizations Delayed Merit Holder Block 7.")

#Create the competing successor Block to the second miner.
block = Block(
  BlockHeader(
    0,
    alt.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    privKeys[1].toPublicKey().serialize(),
    alt.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(privKeys[1], alt.difficulty())
alt.add(block)
print("Generated Reorganizations Delayed Merit Holder Block 8.")

vectors: IO[Any] = open("PythonTests/Vectors/Merit/Reorganizations/DelayedMeritHolder.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
