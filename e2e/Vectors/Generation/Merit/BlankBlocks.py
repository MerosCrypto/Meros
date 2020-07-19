#This used to be a dependency for other generators.
#Now, it's solely used by tests who need a blank chain.

from typing import IO, Any
import json

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

vectors: IO[Any] = open("e2e/Vectors/Merit/BlankBlocks.json", "w")
vectors.write(json.dumps(PrototypeChain(25, keepUnlocked=False).toJSON()))
vectors.close()
