from typing import List, Optional, Any

from ctypes import c_char_p, byref

from e2e.Libs.Milagro.PrivateKeysAndSignatures import MilagroCurve, Big384, FP1Obj, G1Obj, G1_COFACTOR

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement
from e2e.Libs.HashToCurve.Weierstrass import WeierstrassCurve

def clone(
  value: FP1Obj
) -> FP1Obj:
  result: FP1Obj = FP1Obj()
  MilagroCurve.BIG_384_58_copy(result.g, value.g)
  result.XES = value.XES
  return result

class BLS12_381_F1(
  FieldElement
):
  value: FP1Obj

  #pylint: disable=super-init-not-called
  def __init__(
    self,
    value: Any = None
  ) -> None:
    if isinstance(value, List):
      if len(value) != 1:
        raise Exception("Incompatible field element integer list passed to BLS12_381_F1.")
      value = value[0]

    self.value = FP1Obj()
    if (value is None) or (isinstance(value, int) and (value == 0)):
      MilagroCurve.FP_BLS381_zero(byref(self.value))
    elif isinstance(value, int):
      if value == 1:
        MilagroCurve.FP_BLS381_one(byref(self.value))
      else:
        temp: Big384 = Big384()
        MilagroCurve.BIG_384_58_fromBytes(temp, c_char_p(value.to_bytes(48, byteorder="big")))
        MilagroCurve.FP_BLS381_rcopy(byref(self.value), temp)

    #Clone the value.
    elif isinstance(value, FP1Obj):
      self.value = clone(value)
    elif isinstance(value, BLS12_381_F1):
      self.value = clone(value.value)
    else:
      raise Exception("Unknown type passed to BLS12-381 F1 constructor.")

  def __add__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_add(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return BLS12_381_F1(result)

  def __sub__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_sub(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return BLS12_381_F1(result)

  def __mul__(
    self,
    other: Any
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_mul(byref(result), byref(self.value), byref(BLS12_381_F1(other).value))
    return BLS12_381_F1(result)

  def div(
    self,
    other: FieldElement,
    q: int
  ) -> Any:
    return self * (other ** (q - 2))

  def __pow__(
    self,
    exp: int
  ) -> Any:
    result: BLS12_381_F1 = BLS12_381_F1()
    MilagroCurve.FP_BLS381_pow(byref(result.value), byref(self.value), BLS12_381_F1(exp).value.toBig384())
    return result

  def __eq__(
    self,
    other: Any
  ) -> bool:
    return MilagroCurve.FP_BLS381_equals(byref(self.value), byref(other.value)) == 1

  def __ne__(
    self,
    other: Any
  ) -> bool:
    #pylint: disable=superfluous-parens
    return not (self == other)

  def sign(
    self
  ) -> int:
    neg: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_neg(byref(neg), byref(self.value))

    a: Big384 = self.value.toBig384()
    b: Big384 = neg.toBig384()
    #!= -1 because == 1 would cause 0 to identify as negative.
    return 0 if (MilagroCurve.BIG_384_58_comp(a, b) != -1) else 1

  def negative(
    self
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_neg(byref(result), byref(self.value))
    return BLS12_381_F1(result)

  def sqrt(
    self
  ) -> Any:
    result: FP1Obj = FP1Obj()
    MilagroCurve.FP_BLS381_sqrt(byref(result), byref(self.value))
    return BLS12_381_F1(result)

class BLS12_381_G1(
  GroupElement
):
  value: G1Obj

  #pylint: disable=super-init-not-called
  def __init__(
    self,
    x: Any,
    y: Optional[BLS12_381_F1] = None
  ) -> None:
    self.value: G1Obj = G1Obj()
    if isinstance(x, G1Obj):
      MilagroCurve.ECP_BLS381_copy(byref(self.value), byref(x))
    elif isinstance(x, BLS12_381_G1):
      MilagroCurve.ECP_BLS381_copy(byref(self.value), byref(x.value))
    elif (isinstance(x, BLS12_381_F1) and isinstance(y, BLS12_381_F1)):
      xBig: Big384 = x.value.toBig384()
      yBig: Big384 = y.value.toBig384()
      if MilagroCurve.ECP_BLS381_set(byref(self.value), xBig, yBig) != 1:
        raise Exception("Passed invalid x/y to G1 constructor.")
    else:
      raise Exception("Unknown type passed to BLS12-381 G1 constructor.")

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

#pylint: disable=too-few-public-methods
class BLS12381G1Curve(
  WeierstrassCurve
):
  def __init__(
    self
  ) -> None:
    WeierstrassCurve.__init__(
      self,
      BLS12_381_F1,
      BLS12_381_G1,
      False,
      0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab,
      1,
      #Isogenous A/B.
      0x144698a3b8e9433d693a02c96d4982b0ea985383ee66a8d8e8981aefd881ac98936f8da0e0f97f5cf428082d584c1d,
      0x12e2908d11688030018b12e8753eee3b2016c1f0f24f4070a0b9c14fcef35ef55a23215a316ceaa5d1cc48e98e172be0,
      11
    )

  def mapToCurve(
    self,
    u: BLS12_381_F1
  ) -> BLS12_381_G1:
    raise Exception("TODO")
