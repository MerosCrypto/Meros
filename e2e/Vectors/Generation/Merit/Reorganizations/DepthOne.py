from typing import IO, Any
from hashlib import blake2b
import json

from e2e.Classes.Merit.Blockchain import BlockHeader, Block, Blockchain

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

main: Blockchain = Blockchain()
alt: Blockchain = Blockchain()

privKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]

protoRoot: PrototypeChain = PrototypeChain(1, False)
protoRoot.add(1)
root: Blockchain = protoRoot.finish()

main: Blockchain = Blockchain.fromJSON(root.toJSON())
alt: Blockchain = Blockchain.fromJSON(root.toJSON())

main.add(
  PrototypeBlock(root.blocks[-1].header.time + 1200).finish(
    False,
    main.genesis,
    main.blocks[-1].header,
    main.difficulty(),
    privKeys
  )
)

#Create the competing Block to the second miner.
#Since the difficulty is fixed at the start, they're guaranteed to have the same amount of work.
#Because of that, we can't just mine the Block; we need to mine it until it has a lower hash than the above Block.
#Calculate a custom difficulty guaranteed to beat the above Block.
hashAsInt: int = int.from_bytes(main.blocks[-1].header.hash, "big")
difficulty: int = 0
while (difficulty * hashAsInt).bit_length() <= 256:
  difficulty += 1

alt.add(
  PrototypeBlock(
    root.blocks[-1].header.time + 1200,
    minerID = 1
  ).finish(
    False,
    alt.genesis,
    alt.blocks[-1].header,
    difficulty,
    privKeys
  )
)

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/DepthOne.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
