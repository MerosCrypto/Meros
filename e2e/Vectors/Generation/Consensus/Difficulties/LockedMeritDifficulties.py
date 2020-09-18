import json

from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

merit: Merit = Merit.fromJSON(PrototypeChain(49).finish().toJSON())

#Add the Difficulties.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    elements=[SendDifficulty(2, 0, 0), DataDifficulty(2, 1, 0)],
    minerID=0
  ).finish(0, merit)
)

#Close out this, and the next, Checkpoint period to lock our Merit.
for _ in range(9):
  merit.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200,
      minerID=0
    ).finish(0, merit)
  )

#Become Pending.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    minerID=0
  ).finish(1, merit)
)

with open("e2e/Vectors/Consensus/Difficulties/LockedMerit.json", "w") as vectors:
  vectors.write(json.dumps(merit.toJSON()))
