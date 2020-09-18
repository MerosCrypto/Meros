import json

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

proto: PrototypeChain = PrototypeChain(9, False)
merit: Merit = Merit.fromJSON(proto.finish().toJSON())
merit.add(PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(1, merit))
for _ in range(9):
  merit.add(PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(0, merit))

with open("e2e/Vectors/Merit/LockedMerit/LocksUnlocks.json", "w") as vectors:
  vectors.write(json.dumps(merit.toJSON()))
