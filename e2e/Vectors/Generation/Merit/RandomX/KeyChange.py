import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

with open("e2e/Vectors/Merit/RandomX/KeyChange.json", "w") as vectors:
  vectors.write(json.dumps(PrototypeChain(400, keepUnlocked=False).toJSON()))
