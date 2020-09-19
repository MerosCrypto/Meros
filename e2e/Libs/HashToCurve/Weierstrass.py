from typing import Type, Callable, Tuple
import math

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement
from e2e.Libs.HashToCurve.HashToCurve import Curve, SuiteParameters
from e2e.Libs.HashToCurve.Weierstrass import WeierstrassCurve

class WeierstrassCurve(
  Curve
):
  def __init__(
    self,
    fieldType: Type[FieldElement],
    groupType: Type[GroupElement],
    primeField: bool,
    p: int,
    m: int,
    A: int,
    B: int,
    Z: int
  ) -> None:
    Curve.__init__(self, fieldType, groupType, primeField, p, m)
    self.A: fieldType = fieldType(A)
    self.B: fieldType = fieldType(B)
    self.Z: fieldType = fieldType(Z)

class WeierstrassSuiteParameters(
  SuiteParameters
):
  curve: WeierstrassCurve

  def __init__(
    self,
    curve: WeierstrassCurve,
    dst: str,
    k: int,
    L: int,
    expandMessage: Callable[[bytes, int], bytes]
  ) -> None:
    SuiteParameters.__init__(self, curve, dst, k, L, expandMessage)

def mapToCurveSSWUAB0(
  params: WeierstrassSuiteParameters,
  u: FieldElement
) -> Tuple[FieldElement, FieldElement, FieldElement, FieldElement]:
  #Constants.
  C1 = (params.curve.q - 3) // 4
  C2 = math.sqrt(-(params.curve.Z ** 3))

  #Steps 1-3.
  tv1: FieldElement = u ** 2
  tv3: FieldElement = tv1 * params.curve.Z
  tv2: FieldElement = tv3 ** 2

  #Steps 4-7.
  xd: FieldElement = tv2 + tv3
  x1n: FieldElement = (xd + 1) * params.curve.B
  xd *= params.curve.A.negative()

  #Steps 8-9.
  if xd == 0:
    xd = params.curve.A * params.curve.Z

  #Steps 10-12.
  gxd: FieldElement = xd ** 3
  tv2 = (xd ** 2) * params.curve.A

  #Steps 13-15.
  gx1: FieldElement = ((x1n ** 2) + tv2) * x1n

  #Steps 16-20.
  tv2 = gxd
  gx1 += tv2
  tv4 = gxd ** 2
  tv2 = gx1 * gxd
  tv4 *= tv2

  #Steps 21-16.
  y1 = (tv4 ** C1) * tv2
  x2n = tv3 * x1n
  y2 = ((y1 * C2) * tv1) * u

  #Steps 27-28.
  tv2 = (y1 ** 2) * gxd
  xn: FieldElement
  y: FieldElement
  xn, y = (x1n, y1) if tv2 == gx1 else (x2n, y2)
  if u.sign() != y.sign():
    y = y.negative()
  return (xn, xd, y, params.curve.FieldType(1))
