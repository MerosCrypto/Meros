from typing import IO, Any
import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

main: PrototypeChain = PrototypeChain(2)

alt: PrototypeChain = PrototypeChain(1)
alt.timeOffset = alt.timeOffset + 1
for _ in range(2):
  alt.add()

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/TwoHundredThirtyTwo.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
