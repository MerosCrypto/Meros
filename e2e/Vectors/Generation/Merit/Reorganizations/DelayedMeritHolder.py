from typing import IO, List, Any
from hashlib import blake2b
import json

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

privKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]

root: Blockchain = PrototypeChain(5, False).finish()

main: Blockchain = Blockchain.fromJSON(root.toJSON())
main.add(
  PrototypeBlock(
    main.blocks[-1].header.time + 1200,
    minerID=privKeys[1]
  ).finish(
    False,
    main.genesis,
    main.blocks[-1].header,
    main.difficulty(),
    privKeys
  )
)

alt: Blockchain = Blockchain.fromJSON(root.toJSON())
alt.add(
  PrototypeBlock(alt.blocks[-1].header.time + 1200).finish(
    False,
    alt.genesis,
    alt.blocks[-1].header,
    alt.difficulty(),
    privKeys
  )
)
main.add(
  PrototypeBlock(
    alt.blocks[-1].header.time + 1200,
    minerID=privKeys[1]
  ).finish(
    False,
    alt.genesis,
    alt.blocks[-1].header,
    alt.difficulty(),
    privKeys
  )
)

vectors: IO[Any] = open("e2e/Vectors/Merit/Reorganizations/DelayedMeritHolder.json", "w")
vectors.write(json.dumps({
  "main": main.toJSON(),
  "alt": alt.toJSON()
}))
vectors.close()
