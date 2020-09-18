import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

main: PrototypeChain = PrototypeChain(4, False)
alt: PrototypeChain = PrototypeChain(2, False, main.timeOffset + 1)

with open("e2e/Vectors/Merit/Reorganizations/TwoHundredThirtySeven.json", "w") as vectors:
  vectors.write(json.dumps({
    "main": main.toJSON(),
    "alt": alt.toJSON()
  }))
