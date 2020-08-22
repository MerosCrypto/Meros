from typing import IO, Any
import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

alt: PrototypeChain = PrototypeChain(380, keepUnlocked=False)
alt.timeOffset = alt.timeOffset + 1
for _ in range(30):
  alt.add()

vectors: IO[Any] = open("e2e/Vectors/Merit/RandomX/ChainReorgDifferentKey.json", "w")
vectors.write(json.dumps({
  "main": PrototypeChain(400, keepUnlocked=False).toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
