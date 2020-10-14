from e2e.Libs.HashToCurve.Elements import FieldElement
from e2e.Libs.HashToCurve.Weierstrass import mapToCurveSSWU, mapToCurveSSWU3Mod4
from e2e.Libs.BLS import MerosParameters

from e2e.Tests.Errors import TestError

#Specifically tests the SSWU implementation against the SSWU 3 mod 4 optimized implementation.
def SSWU3Mod4MapToCurveTest() -> None:
  params: MerosParameters = MerosParameters()
  #Generate some random field elements to map.
  for uListInt in params.hashToField(("").encode("utf-8"), 16):
    u: FieldElement = params.curve.FieldType(uListInt)
    if mapToCurveSSWU(params, u) != mapToCurveSSWU3Mod4(params, u):
      raise TestError("Optimized SSWU differs from non-optimized.")
