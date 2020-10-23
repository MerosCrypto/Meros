from typing import List, Tuple, Type, Any
from ctypes import cdll, Structure, POINTER, c_int
import os

from e2e.Libs.Milagro.PrivateKeysAndSignatures import byref, Big384, FP1Obj, G1, MilagroCurve, MilagroPairing

#pylint: disable=too-few-public-methods
class FP2Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [("a", FP1Obj), ("b", FP1Obj)]

  def isLargerThanNegative(
    self
  ) -> bool:
    yNeg: FP2Obj = FP2Obj()
    MilagroPairing.FP2_BLS381_neg(byref(yNeg), byref(self))

    a: Big384 = self.b.toBig384()
    b: Big384 = yNeg.b.toBig384()
    cmpRes: int = MilagroCurve.BIG_384_58_comp(a, b)

    if cmpRes == 0:
      a = self.a.toBig384()
      b = yNeg.a.toBig384()
      cmpRes = MilagroCurve.BIG_384_58_comp(a, b)

    return cmpRes == 1

FP2: Any = POINTER(FP2Obj)

#pylint: disable=too-few-public-methods
class FP4Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [
    ("a", FP2Obj),
    ("b", FP2Obj),
    ("c", FP2Obj)
  ]
FP4: Any = POINTER(FP4Obj)

#pylint: disable=too-few-public-methods
class FP12Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [
    ("a", FP4Obj),
    ("b", FP4Obj),
    ("c", FP4Obj),
    ("type", c_int)
  ]
FP12: Any = POINTER(FP12Obj)

#pylint: disable=too-few-public-methods
class G2Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [
    ("x", FP2Obj),
    ("y", FP2Obj),
    ("z", FP2Obj)
  ]
G2: Any = POINTER(G2Obj)

MilagroPairing.FP2_BLS381_neg.argtypes = [FP2, FP2]
MilagroPairing.FP2_BLS381_neg.restype = None

MilagroPairing.FP2_BLS381_reduce.argtypes = [FP2]
MilagroPairing.FP2_BLS381_reduce.restype = None

MilagroPairing.FP2_BLS381_from_BIGs.argtypes = [FP2, Big384, Big384]
MilagroPairing.FP2_BLS381_from_BIGs.restype = None

MilagroPairing.ECP2_BLS381_inf.argtypes = [G2]
MilagroPairing.ECP2_BLS381_inf.restype = None

MilagroPairing.ECP2_BLS381_isinf.argtypes = [G2]
MilagroPairing.ECP2_BLS381_isinf.restype = c_int

MilagroPairing.ECP2_BLS381_generator.argtypes = [G2]
MilagroPairing.ECP2_BLS381_generator.restype = None

MilagroPairing.ECP2_BLS381_setx.argtypes = [G2, FP2]
MilagroPairing.ECP2_BLS381_setx.restype = c_int

MilagroPairing.ECP2_BLS381_add.argtypes = [G2, G2]
MilagroPairing.ECP2_BLS381_add.restype = c_int

MilagroPairing.ECP2_BLS381_mul.argtypes = [G2, Big384]
MilagroPairing.ECP2_BLS381_mul.restype = None

MilagroPairing.ECP2_BLS381_neg.argtypes = [G2]
MilagroPairing.ECP2_BLS381_neg.restype = None

MilagroPairing.ECP2_BLS381_get.argtypes = [FP2, FP2, G2]
MilagroPairing.ECP2_BLS381_get.restype = c_int

MilagroPairing.FP2_BLS381_from_BIGs.argtypes = [FP2, Big384, Big384]
MilagroPairing.FP2_BLS381_from_BIGs.restype = None

MilagroPairing.PAIR_BLS381_ate.argtypes = [FP12, G2, G1]
MilagroPairing.PAIR_BLS381_ate.restype = None

MilagroPairing.PAIR_BLS381_fexp.argtypes = [FP12]
MilagroPairing.PAIR_BLS381_fexp.restype = None

MilagroPairing.FP12_BLS381_mul.argtypes = [FP12, FP12]
MilagroPairing.FP12_BLS381_mul.restype = None

MilagroPairing.FP12_BLS381_ssmul.argtypes = [FP12, FP12]
MilagroPairing.FP12_BLS381_ssmul.restype = None

MilagroPairing.FP12_BLS381_isunity.argtypes = [FP12]
MilagroPairing.FP12_BLS381_isunity.restype = c_int
