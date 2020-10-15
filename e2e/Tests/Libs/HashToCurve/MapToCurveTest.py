from typing import Dict, List, Any
import json

from e2e.Libs.HashToCurve.Elements import GroupElement
from e2e.Libs.HashToCurve.HashToCurve import SuiteParameters
from e2e.Libs.BLS import MerosParameters

from e2e.Tests.Errors import TestError

def MapToCurveTest() -> None:
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Libs/HashToCurve/MapToCurve.json", "r") as file:
    vectors = json.loads(file.read())

  for curve in vectors:
    #Same commentary from HashToField applies here.
    params: SuiteParameters
    if curve["curve"] == "BLS12381G1":
      params = MerosParameters()
    else:
      raise Exception("Testing an unknown curve.")

    for vector in curve["vectors"]:
      result: GroupElement = params.curve.mapToCurve(params.curve.FieldType(int(vector["u"], 16)))
      if (result.x != vector["x"]) or (result.y != vector["y"]):
        raise TestError("Incorrect map.")
