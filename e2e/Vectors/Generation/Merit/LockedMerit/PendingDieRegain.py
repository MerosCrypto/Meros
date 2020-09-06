import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

proto: PrototypeChain = PrototypeChain(1, False)
merit: Merit = Merit.fromJSON(proto.finish().toJSON())

#Use up all of our Blocks with Merit, except the last one.
for i in range(98):
  merit.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200,
      minerID=(PrivateKey(1) if i == 0 else 1)
    ).finish(0, merit)
  )

#Right before the end, move to pending.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    minerID=1
  ).finish(1, merit)
)

#Have our Merit die.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    minerID=1
  ).finish(0, merit)
)

#Regain Merit.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    minerID=0
  ).finish(0, merit)
)

with open("e2e/Vectors/Merit/LockedMerit/PendingDieRegain.json", "w") as vectors:
  vectors.write(json.dumps(merit.toJSON()))
