from typing import Dict, List, Any
import json

from e2e.Libs.HashToCurve.Elements import GroupElement
from e2e.Libs.HashToCurve.HashToCurve import SuiteParameters
from e2e.Libs.BLS import MerosParameters

from e2e.Tests.Errors import TestError

def HashToCurveTest() -> None:
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Libs/HashToCurve/HashToCurve.json", "r") as file:
    vectors = json.loads(file.read())

  for suite in vectors:
    params: SuiteParameters
    if suite["suite"] == "BLS12381G1_XMD:SHA-256_SSWU_RO_":
      params = MerosParameters()
    else:
      raise Exception("Testing an unknown suite.")
    #Override the dst.
    params.dst = suite["dst"]

    for vector in suite["vectors"]:
      result: GroupElement = params.hashToCurve(vector["msg"].encode("utf-8"))
      if (result.x != vector["x"]) or (result.y != vector["y"]):
        raise TestError("Incorrect point.")
