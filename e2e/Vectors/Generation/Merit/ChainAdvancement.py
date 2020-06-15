from typing import IO, Any
import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

vectors: IO[Any] = open("e2e/Vectors/Merit/ChainAdvancement.json", "w")
vectors.write(json.dumps([
  PrototypeChain(25, keepUnlocked=False).finish().toJSON(),
  PrototypeChain(25).finish().toJSON()
]))
vectors.close()
