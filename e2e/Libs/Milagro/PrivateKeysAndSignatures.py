from typing import Type, Union, List, Tuple, Any
from ctypes import cdll, Structure, Array, POINTER, \
                   c_char_p, c_int64, c_int32, c_int
import os

#Import the Milagro Curve library.
#pylint: disable=invalid-name
MilagroCurve: Any
if os.name == "nt":
  MilagroCurve = cdll.LoadLibrary("e2e/Libs/incubator-milagro-crypto-c/build/lib/amcl_curve_BLS381")
else:
  MilagroCurve = cdll.LoadLibrary("e2e/Libs/incubator-milagro-crypto-c/build/lib/libamcl_curve_BLS381.so")

#Define the structures.
Big384: Type[Array[c_int64]] = c_int64 * 7
DBig384: Type[Array[c_int64]] = c_int64 * 14

#pylint: disable=too-few-public-methods
class OctetObj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [
    ("len", c_int),
    ("max", c_int),
    ("val", c_char_p)
  ]
Octet: Any = POINTER(OctetObj)

#pylint: disable=too-few-public-methods,
class FP1Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [("g", Big384), ("XES", c_int32)]
FP1: Any = POINTER(FP1Obj)

#pylint: disable=too-few-public-methods
class G1Obj(
  Structure
):
  _fields_: List[Tuple[str, Type[Any]]] = [
    ("x", FP1Obj),
    ("y", FP1Obj),
    ("z", FP1Obj)
  ]
G1: Any = POINTER(G1Obj)

MilagroCurve.BIG_384_58_copy.argtypes = [Big384, Big384]
MilagroCurve.BIG_384_58_copy.restype = None

MilagroCurve.BIG_384_58_mod.argtypes = [Big384, Big384]
MilagroCurve.BIG_384_58_mod.restype = None

MilagroCurve.BIG_384_58_comp.argtypes = [Big384, Big384]
MilagroCurve.BIG_384_58_comp.restype = c_int

MilagroCurve.BIG_384_58_toBytes.argtypes = [c_char_p, Big384]
MilagroCurve.BIG_384_58_toBytes.restype = None

MilagroCurve.BIG_384_58_fromBytesLen.argtypes = [Big384, c_char_p, c_int]
MilagroCurve.BIG_384_58_fromBytesLen.restype = None

MilagroCurve.FP_BLS381_neg.argtypes = [FP1, FP1]
MilagroCurve.FP_BLS381_neg.restype = None

MilagroCurve.FP_BLS381_redc.argtypes = [Big384, FP1]
MilagroCurve.FP_BLS381_redc.restype = None

MilagroCurve.ECP_BLS381_inf.argtypes = [G1]
MilagroCurve.ECP_BLS381_inf.restype = None

MilagroCurve.ECP_BLS381_copy.argtypes = [G1, G1]
MilagroCurve.ECP_BLS381_copy.restype = None

MilagroCurve.ECP_BLS381_isinf.argtypes = [G1]
MilagroCurve.ECP_BLS381_isinf.restype = c_int

MilagroCurve.ECP_BLS381_setx.argtypes = [G1, Big384, c_int]
MilagroCurve.ECP_BLS381_setx.restype = c_int

MilagroCurve.ECP_BLS381_add.argtypes = [G1, G1]
MilagroCurve.ECP_BLS381_add.restype = None

MilagroCurve.ECP_BLS381_mul.argtypes = [G1, Big384]
MilagroCurve.ECP_BLS381_mul.restype = None

MilagroCurve.ECP_BLS381_neg.argtypes = [G1]
MilagroCurve.ECP_BLS381_neg.restype = None

MilagroCurve.ECP_BLS381_get.argtypes = [Big384, Big384, G1]
MilagroCurve.ECP_BLS381_get.restype = c_int

MilagroCurve.ECP_BLS381_mapit.argtypes = [G1, Octet]
MilagroCurve.ECP_BLS381_mapit.restype = None

rUnion: Union[c_int64, Array[c_int64]] = Big384.in_dll(MilagroCurve, "CURVE_Order_BLS381")
if isinstance(rUnion, Array[c_int64]):
  r: Big384 = rUnion
else:
  raise Exception("Couldn't load the BLS curve order.")
