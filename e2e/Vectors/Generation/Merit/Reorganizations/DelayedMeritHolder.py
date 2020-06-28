from typing import IO, Any
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Merit import Blockchain, Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

secondPrivKey: PrivateKey = PrivateKey(1)

root: Blockchain = PrototypeChain(5, False).finish()

main: Merit = Merit.fromJSON(root.toJSON())
main.add(
  PrototypeBlock(
    main.blockchain.blocks[-1].header.time + 1200,
    minerID=secondPrivKey
  ).finish(0, main)
)

alt: Merit = Merit.fromJSON(root.toJSON())
alt.add(
  PrototypeBlock(alt.blockchain.blocks[-1].header.time + 1200).finish(0, alt)
)
main.add(
  PrototypeBlock(
    alt.blockchain.blocks[-1].header.time + 1200,
    minerID=secondPrivKey
  ).finish(0, alt)
)

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/DelayedMeritHolder.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
