import json

from e2e.Classes.Merit.Merit import Blockchain, Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

protoRoot: PrototypeChain = PrototypeChain(1, False)
protoRoot.add(1)
root: Blockchain = protoRoot.finish()

main: Merit = Merit.fromJSON(root.toJSON())
alt: Merit = Merit.fromJSON(root.toJSON())

main.add(
  PrototypeBlock(main.blockchain.blocks[-1].header.time + 1200).finish(0, main)
)

#Create the competing Block to the second miner.
#Since the difficulty is fixed at the start, they're guaranteed to have the same amount of work.
#Because of that, we can't just mine the Block; we need to mine it until it has a lower hash than the above Block.
#Calculate a custom difficulty guaranteed to beat the above Block.
hashAsInt: int = int.from_bytes(main.blockchain.blocks[-1].header.hash, "little")
timeOffset: int = 1201
alt.blockchain.difficulties[-1] = 0
while int.from_bytes(
  PrototypeBlock(
    alt.blockchain.blocks[-1].header.time + timeOffset,
    minerID=1
  ).finish(0, alt).header.hash,
  "little"
) > hashAsInt:
  timeOffset += 1

alt.add(
  PrototypeBlock(alt.blockchain.blocks[-1].header.time + timeOffset, minerID=1).finish(0, alt)
)

with open("e2e/Vectors/Merit/Reorganizations/DepthOne.json", "w") as vectors:
  vectors.write(json.dumps({
    "main": main.toJSON(),
    "alt": alt.toJSON()
  }))
