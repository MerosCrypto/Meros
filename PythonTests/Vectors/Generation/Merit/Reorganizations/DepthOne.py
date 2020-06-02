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

#Create the Block to the first miner.
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
block.mine(privKeys[0], main.difficulty())
main.add(block)
alt.add(block)
print("Generated Reorganizations Depth One Block 1.")

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
alt.add(block)
print("Generated Reorganizations Depth One Block 2.")

#Create the competing Block to the first miner.
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
block.mine(privKeys[0], main.difficulty())
main.add(block)
print("Generated Reorganizations Depth One Block 3.")

#Create the competing Block to the second miner.
#Since the difficulty is fixed at the start, they're guaranteed to have the same amount of work.
#Because of that, we can't just mine the Block; we need to mine it until it has a lower hash than the above Block.
difficulty: int = alt.difficulty()
while True:
  block = Block(
    BlockHeader(
      0,
      alt.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      1,
      alt.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )
  block.mine(privKeys[1], difficulty)

  continueOuter: bool = True
  for b in range(32):
    #If this hash is greater, boost the difficulty and re-mine it.
    if block.header.hash[b] > main.blocks[-1].header.hash[b]:
      difficulty *= 2
      break
    #If the hash is lower, break.
    elif block.header.hash[b] < main.blocks[-1].header.hash[b]:
      continueOuter = False
      break
  if not continueOuter:
    break
alt.add(block)
print("Generated Reorganizations Depth One Block 4.")

vectors: IO[Any] = open("PythonTests/Vectors/Merit/Reorganizations/DepthOne.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
