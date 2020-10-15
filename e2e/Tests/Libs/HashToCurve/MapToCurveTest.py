from typing import Dict, List, Any
import json

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
      for i, u in enumerate(params.hashToField(vector["msg"].encode("utf-8"), 2)):
        #This utilization of 0 is only valid because Meros deals with FP1s.
        #As I have no idea the encoding for FPXs, though I assume they're just concat'd.
        #I'm not writing what I think would be the proper serialization format.
        #Just noting that this isn't generic because of that.
        #-- Kayaba
        if hex(u[0])[2:].rjust(96, '0') != vector["u"][i]:
          raise TestError("Incorrect field point.")
