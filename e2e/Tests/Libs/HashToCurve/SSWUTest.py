from typing import Tuple

from e2e.Libs.HashToCurve.Elements import FieldElement
from e2e.Libs.HashToCurve.Weierstrass import mapToCurveSSWU, mapToCurveSSWUStraightLine, mapToCurveSSWU3Mod4
from e2e.Libs.BLS import MerosParameters

from e2e.Tests.Errors import TestError

#Tests the non-straight line generic SSWU impl against the straight line one against the optimized 3 mod 4 one.
def SSWUTest() -> None:
  params: MerosParameters = MerosParameters()
  #Generate some random field elements to map.
  for uListInt in params.hashToField(("").encode("utf-8"), 16):
    u: FieldElement = params.curve.FieldType(uListInt)
    generic: Tuple[FieldElement, FieldElement] = mapToCurveSSWU(params, u)
    straightLine: Tuple[FieldElement, FieldElement] = mapToCurveSSWUStraightLine(params, u)
    threeMod4: Tuple[FieldElement, FieldElement] = mapToCurveSSWU3Mod4(params, u)
    if (generic[0] != straightLine[0]) or (generic[1] != straightLine[1]):
      raise TestError("Generic SSWU differs from Straight Line.")
    if (generic[0] != threeMod4[0]) or (generic[1] != threeMod4[1]):
      raise TestError("Generic SSWU differs from 3 mod 4.")
