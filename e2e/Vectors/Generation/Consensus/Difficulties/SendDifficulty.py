import json

from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(25)
proto.add(elements=[SendDifficulty(2, 0, 0)])
for _ in range(24):
  proto.add()
proto.add(elements=[SendDifficulty(1, 1, 0)])

proto.add(elements=[MeritRemoval(SendDifficulty(1, 1, 0), SendDifficulty(2, 1, 0), True)])

for _ in range(50):
  proto.add()

with open("e2e/Vectors/Consensus/Difficulties/SendDifficulty.json", "w") as vectors:
  vectors.write(json.dumps(proto.toJSON()))
