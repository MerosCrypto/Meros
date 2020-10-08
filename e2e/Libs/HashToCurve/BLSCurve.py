from typing import List, Any

from ctypes import byref
import math

from e2e.Libs.Milagro.PrivateKeysAndSignatures import MilagroCurve, Big384, FP1Obj, G1Obj, G1_COFACTOR

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement
from e2e.Libs.HashToCurve.Weierstrass import WeierstrassCurve

def clone(
  value: FP1Obj
) -> FP1Obj:
  result: FP1Obj = FP1Obj()
  MilagroCurve.BIG_384_58_copy(byref(result.g), byref(value.g))
  result.XES = value.XES
  return result

class BLS12_381_F1(
  FieldElement
):
  value: FP1Obj

  #pylint: disable=super-init-not-called
  def __init__(
    self,
    value: Any
  ) -> None:
    if isinstance(value, List):
      if len(value) != 1:
        raise Exception("Incompatible field element integer list passed to BLS12_381_F1.")
      value = value[0]

    self.value = FP1Obj()
    if value is None:
      MilagroCurve.FP_BLS381_zero(byref(self.value))
    elif isinstance(value, int):
      if value >= ((2 ** 31) - 1):
        raise Exception("Cannot create a FieldElement from an integer exceeding the signed 32-bit integer bound.")

      temp: Big384 = Big384()
      MilagroCurve.BIG_384_58_one(temp)
      MilagroCurve.BIG_384_58_imul(temp, temp, value)

      MilagroCurve.FP_BLS381_rcopy(byref(self.value), temp)

    #Clone the value.
    elif isinstance(value, FP1Obj):
      self.value = clone(value)
    elif isinstance(value, BLS12_381_F1):
      self.value = clone(value.value)

  def __add__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_add(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return result

  def __mul__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_mul(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return result

  def __div__(
    self,
    other: int
  ) -> Any:
    if other == 1:
      return BLS12_381_F1(self)
    if (other < 1) or (not math.log2(other).is_integer()):
      raise Exception("Only power of two divisors are valid.")

    result = BLS12_381_F1(self)
    while other != 1:
      MilagroCurve.FP_BLS381_div2(byref(result.value), byref(result.value))
      other = other // 2

  def __pow__(
    self,
    exp: int
  ) -> Any:
    if exp < 1:
      raise Exception("Negative/zero exponents aren't supported.")

    result: FieldElement = BLS12_381_F1(self.value)
    for _ in range(1, exp):
      result *= self

  def __eq__(
    self,
    other: Any
  ) -> bool:
    return MilagroCurve.FP_BLS381_equals(byref(self.value), byref(other.value)) == 1

  def sign(
    self
  ) -> int:
    neg: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_neg(byref(neg), byref(self.value))

    a: Big384 = Big384()
    b: Big384 = Big384()
    MilagroCurve.FP_BLS381_redc(a, byref(self.value))
    MilagroCurve.FP_BLS381_redc(b, byref(neg))
    #!= -1 because == 1 would cause 0 to identify as negative.
    return 0 if (MilagroCurve.BIG_384_58_comp(a, b) != -1) else 1

  def negative(
    self
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_neg(byref(result), byref(self.value))
    return result

class BLS12_381_G1(
  GroupElement
):
  value: G1Obj

  def __init__(
    self,
    x: G1Obj
  ) -> None:
    self.value: G1Obj = G1Obj()
    MilagroCurve.ECP_BLS381_copy(byref(self.value), byref(x))

  def __add__(
    self,
    other: Any
  ) -> GroupElement:
    result: G1Obj = G1Obj()
    MilagroCurve.ECP_BLS381_add(byref(result), byref(self.value))
    MilagroCurve.ECP_BLS381_add(byref(result), byref(other.value))
    return BLS12_381_G1(result)

  def clearCofactor(
    self
  ) -> GroupElement:
    result: BLS12_381_G1 = BLS12_381_G1(self.value)
    MilagroCurve.ECP_BLS381_mul(byref(result.value), G1_COFACTOR)
    return result

#pylint: disable=invalid-name
BLS12_381_G1_CURVE: WeierstrassCurve = WeierstrassCurve(
  BLS12_381_F1,
  BLS12_381_G1,
  False,
  0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab,
  1,
  0,
  4,
  11
)
