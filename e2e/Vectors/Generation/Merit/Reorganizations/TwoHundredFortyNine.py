from typing import Dict, List, Any
import json

from e2e.Libs.BLS import PrivateKey
from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

root: List[Dict[str, Any]] = PrototypeChain(9, False).finish().toJSON()
main: Merit = Merit.fromJSON(root)
alt: Merit = Merit.fromJSON(root)

for _ in range(2):
  main.add(
    PrototypeBlock(main.blockchain.blocks[-1].header.time + 1200).finish(0, main)
  )

#Create a fork Block with a lower hash.
#Same principle as DepthOne.
hashAsInt: int = int.from_bytes(main.blockchain.blocks[-2].header.hash, "little")
k: int = 1
while int.from_bytes(
  PrototypeBlock(
    alt.blockchain.blocks[-1].header.time + 1200,
    minerID=PrivateKey(k)
  ).finish(0, alt).header.hash,
  "little"
) > hashAsInt:
  k += 1
alt.add(
  PrototypeBlock(
    alt.blockchain.blocks[-1].header.time + 1200,
    minerID=PrivateKey(k)
  ).finish(0, alt)
)

#Now, create a tail Block with a higher hash.
hashAsInt = int.from_bytes(main.blockchain.blocks[-1].header.hash, "little")
#Move on to the next BLS key.
k += 1
while int.from_bytes(
  PrototypeBlock(
    alt.blockchain.blocks[-1].header.time + 1200,
    minerID=PrivateKey(k)
  ).finish(0, alt).header.hash,
  "little"
) < hashAsInt:
  k += 1
alt.add(
  PrototypeBlock(
    alt.blockchain.blocks[-1].header.time + 1200,
    minerID=PrivateKey(k)
  ).finish(0, alt)
)

with open("e2e/Vectors/Merit/Reorganizations/TwoHundredFortyNine.json", "w") as vectors:
  vectors.write(json.dumps({
    "main": main.toJSON(),
    "alt": alt.toJSON()
  }))
