from typing import Type, Callable, List, Any
from abc import ABC, abstractmethod

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement
from e2e.Libs.HashToCurve.Weierstrass import WeierstrassCurve

class BLS12_381_F1(
  FieldElement
):
  pass

class BLS12_381_G1(
  GroupElement
):
  def __add__(
    self,
    other: Any
  ) -> Any:
    raise Exception("TODO")

  def clearCofactor(
    self
  ) -> Any:
    raise Exception("TODO")

BLS12_381_G1_CURVE = WeierstrassCurve(
  BLS12_381_F1,
  BLS12_381_G1,
  False,
  0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab,
  1,
  0,
  4,
  11
)
