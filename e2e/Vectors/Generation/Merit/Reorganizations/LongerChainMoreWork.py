import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

main: PrototypeChain = PrototypeChain(25, False)
alt: PrototypeChain = PrototypeChain(15, False)

#Update the time of the alt chain to be longer, causing a lower amount of work per Block.
#Compensate by adding more Blocks overall.
alt.timeOffset = 1201
for _ in range(14):
  alt.add()

with open("e2e/Vectors/Merit/Reorganizations/LongerChainMoreWork.json", "w") as vectors:
  vectors.write(json.dumps({
    "main": main.toJSON(),
    "alt": alt.toJSON()
  }))
