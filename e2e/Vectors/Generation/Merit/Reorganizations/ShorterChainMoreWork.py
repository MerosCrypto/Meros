from typing import Dict, List, IO, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

privKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())

main: PrototypeChain = PrototypeChain(25, False)
alt: PrototypeChain = PrototypeChain(15, False)

#Update the time of the alt chain to be much short, causing a much higher amount of work per Block.
alt.timeOffset = 1
for _ in range(5):
  alt.add(1)

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/ShorterChainMoreWork.json", "w")
vectors.write(json.dumps({
  "main": main.finish().toJSON(),
  "alt": alt.finish().toJSON()
}))
vectors.close()
