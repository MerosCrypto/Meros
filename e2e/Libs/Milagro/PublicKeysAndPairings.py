from typing import List, Tuple, Type, Any
from ctypes import cdll, Structure, POINTER, c_int
import os

from e2e.Libs.Milagro.PrivateKeysAndSignatures import Big384, FP1Obj, G1

#Import the Milagro Curve library.
#pylint: disable=invalid-name
MilagroPairing: Any
if os.name == "nt":
  MilagroPairing = cdll.LoadLibrary("e2e/Libs/incubator-milagro-crypto-c/build/lib/amcl_pairing_BLS381")
else:
  MilagroPairing = cdll.LoadLibrary("e2e/Libs/incubator-milagro-crypto-c/build/lib/libamcl_pairing_BLS381.so")

#pylint: disable=too-few-public-methods
class FP2Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [("a", FP1Obj), ("b", FP1Obj)]
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
