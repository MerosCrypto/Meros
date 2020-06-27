from typing import IO, Any
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

secondPrivKey: PrivateKey = PrivateKey(1)

root: Blockchain = PrototypeChain(5, False).finish()

main: Blockchain = Blockchain.fromJSON(root.toJSON())
main.add(
  PrototypeBlock(
    main.blocks[-1].header.time + 1200,
    minerID=secondPrivKey
  ).finish(0, main.blocks[-1].header, main.difficulty())
)

alt: Blockchain = Blockchain.fromJSON(root.toJSON())
alt.add(
  PrototypeBlock(alt.blocks[-1].header.time + 1200).finish(
    0,
    alt.blocks[-1].header,
    alt.difficulty()
  )
)
main.add(
  PrototypeBlock(
    alt.blocks[-1].header.time + 1200,
    minerID=secondPrivKey
  ).finish(0, alt.blocks[-1].header, alt.difficulty())
)

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/DelayedMeritHolder.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
