from typing import IO, Any
import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

vectors: IO[Any] = open("e2e/Vectors/Merit/RandomX/KeyChange.json", "w")
vectors.write(json.dumps(PrototypeChain(400, keepUnlocked=False).toJSON()))
vectors.close()
