from typing import Dict, List, Any
import json
import hashlib

from e2e.Libs.HashToCurve.ExpandMessage import expandMessageXMD

from e2e.Tests.Errors import TestError

def XMDTest() -> None:
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Libs/HashToCurve/XMD.json", "r") as file:
    vectors = json.loads(file.read())

  for h in range(len(vectors)):
    hashVectors: Dict[str, Any] = vectors[h]
    for v in range(len(hashVectors["vectors"])):
      vector: Dict[str, Any] = hashVectors["vectors"][v]
      if expandMessageXMD(
        #pylint: disable=cell-var-from-loop
        lambda data: hashlib.new(hashVectors["H"], data),
        hashVectors["dst"],
        vector["msg"].encode("utf-8"),
        vector["outputLength"]
      ) != bytes.fromhex(vector["uniform"]):
        raise TestError("Invalid XMD function for vector " + str(h) + " " + str(v) + ".")
