from typing import IO, Any
import json

from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(25)
proto.add(elements=[SendDifficulty(2, 0, 0)])
for _ in range(24):
  proto.add(elements=[SendDifficulty(1, 1, 0)])

#Create MeritRemovals by reusing nonces.
proto.add(elements=[MeritRemoval(SendDifficulty(2, 0, 0), SendDifficulty(1, 0, 0), True)])
proto.add(elements=[MeritRemoval(SendDifficulty(1, 1, 0), SendDifficulty(2, 1, 0), True)])

for _ in range(50):
  proto.add()

vectors: IO[Any] = open("e2e/Vectors/Consensus/Difficulties/SendDifficulty.json", "w")
vectors.write(json.dumps({
  "blockchain": proto.toJSON()
}))
vectors.close()
