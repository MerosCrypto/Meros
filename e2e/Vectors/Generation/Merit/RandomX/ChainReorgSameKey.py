import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

alt: PrototypeChain = PrototypeChain(390, keepUnlocked=False)
alt.timeOffset = alt.timeOffset + 1
for _ in range(20):
  alt.add()

with open("e2e/Vectors/Merit/RandomX/ChainReorgSameKey.json", "w") as vectors:
  vectors.write(json.dumps({
    "main": PrototypeChain(400, keepUnlocked=False).toJSON(),
    "alt": alt.toJSON()
  }))
