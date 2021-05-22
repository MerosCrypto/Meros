from typing import List, Tuple, Union
import hashlib

#pylint: disable=no-name-in-module
from gmpy2 import mpz

from e2e.Libs.Ristretto.FieldElement import FieldElement, q, d
from e2e.Libs.Ristretto.Scalar import Scalar
from e2e.Libs.Ristretto.Point import Point, BASEPOINT

#BASEPOINT is imported to be exported.
_: Point = BASEPOINT

#These should be removed for their actual calculations.
SQRT_M1: FieldElement = FieldElement(19681161376707505956807079304988542015446066515923890162744021073123829784752)
INVSQRT_A_MINUS_D: FieldElement = FieldElement(54469307008909316920995813868745141605393597292927456921205312896311721017578)
SQRT_AD_MINUS_ONE: FieldElement = FieldElement(25063068953384623474111414158702152701244531502492656460079210482610430750235)

def sqrRootRatio(
  u: FieldElement,
  v: FieldElement
) -> Tuple[bool, FieldElement]:
  v3: FieldElement = v ** mpz(3)
  v7: FieldElement = v3 * v3 * v
  r: FieldElement = u * v3 * ((u * v7) ** ((q - mpz(5)) // mpz(8)))
  c: FieldElement = v * (r ** mpz(2))
  correctSign: bool = c == u
  flippedSign: bool = c == u.negate()
  flippedSignI: bool = c == (u.negate() * SQRT_M1)
  if flippedSign or flippedSignI:
    r = r * SQRT_M1
  if r.isNegative():
    r = r.negate()
  return (correctSign or flippedSign, r)

class RistrettoPoint:
  underlying: Point

  def serialize(
    self
  ) -> bytes:
    #pylint: disable=invalid-name
    X: FieldElement = self.underlying.underlying[0]
    #pylint: disable=invalid-name
    Y: FieldElement = self.underlying.underlying[1]
    #pylint: disable=invalid-name
    Z: FieldElement = FieldElement(1)
    #pylint: disable=invalid-name
    T: FieldElement = X * Y

    u1: FieldElement = (Z + Y) * (Z - Y)
    u2: FieldElement = T
    root: Tuple[bool, FieldElement] = sqrRootRatio(FieldElement(1), u1 * u2 * u2)
    #pylint: disable=invalid-name
    I: FieldElement = root[1]

    #pylint: disable=invalid-name
    D1: FieldElement = u1 * I
    #pylint: disable=invalid-name
    D2: FieldElement = u2 * I

    #pylint: disable=invalid-name
    Zinv: FieldElement = D1 * D2 * T

    #pylint: disable=invalid-name
    D: FieldElement
    if (T * Zinv).isNegative():
      (X, Y) = (Y * SQRT_M1, X * SQRT_M1)
      D = D1 * INVSQRT_A_MINUS_D
    else:
      D = D2

    if (X * Zinv).isNegative():
      Y = Y.negate()
    res: FieldElement = (Z - Y) * D
    if res.isNegative():
      res = res.negate()
    return int(res.underlying).to_bytes(32, "little")

  def __init__(
    self,
    point: Union[Point, bytes]
  ) -> None:
    if isinstance(point, bytes):
      #Decode.
      s: FieldElement = FieldElement(int.from_bytes(point, "little"))
      if s.isNegative():
        raise Exception("Negative field element.")
      u1: FieldElement = FieldElement(1) + (s * s).negate()
      u2: FieldElement = FieldElement(1) - (s * s).negate()
      v: FieldElement = (d * (u1 * u1)).negate() - (u2 * u2)
      root: bool
      #pylint: disable=invalid-name
      I: FieldElement
      (root, I) = sqrRootRatio(FieldElement(1), v * u2 * u2)
      if not root:
        raise Exception("Point doesn't have a root.")
      #pylint: disable=invalid-name
      Dx: FieldElement = I * u2
      #pylint: disable=invalid-name
      Dy: FieldElement = I * Dx * v
      x: FieldElement = FieldElement(2) * s * Dx
      if x.isNegative():
        x = x.negate()
      y: FieldElement = u1 * Dy
      if (y == FieldElement(0)) or (x * y).isNegative():
        raise Exception("y is 0 or negative product.")
      self.underlying = Point([x, y])
      if self.serialize() != point:
        raise Exception("Non-canonical or invalid encoding used.")
    else:
      self.underlying = point

  def __mul__(
    self,
    scalar: "RistrettoScalar"
  ) -> "RistrettoPoint":
    return RistrettoPoint(self.underlying * scalar.underlying)

  def __eq__(
    self,
    other: "RistrettoPoint"
  ) -> bool:
    return (
      (self.underlying.underlying[0] * other.underlying.underlying[1]) == (
        self.underlying.underlying[1] * other.underlying.underlying[0]
      )
    ) or (
      (self.underlying.underlying[1] * other.underlying.underlying[1]) == (
        self.underlying.underlying[0] * other.underlying.underlying[0]
      )
    )

#This should be moved into our Hash to Curve folder, as it's literally a hash to curve algorithm.
#Also, this isn't used in Meros. It just makes our implementation complete and enables further testing of this code.
#pylint: disable=too-many-locals
def hashToCurve(
  msg: bytes
) -> RistrettoPoint:
  #pylint: disable=invalid-name
  ONE: FieldElement = FieldElement(1)

  hashed: bytes = hashlib.sha512(msg).digest()
  res: List[Point] = []
  for i in range(2):
    r0: FieldElement = FieldElement(int.from_bytes(hashed[i * 32 : (i + 1) * 32], "little") & ((2 ** 255) - 1))
    r: FieldElement = SQRT_M1 * r0 * r0
    #pylint: disable=invalid-name
    Ns: FieldElement = (r + ONE) * (ONE - (d * d))
    c: FieldElement = FieldElement(0) - ONE
    D: FieldElement = (c - (d * r)) * (r + d)

    isSquare: bool
    s: FieldElement
    (isSquare, s) = sqrRootRatio(Ns, D)
    sr0: FieldElement = s * r0
    if not sr0.isNegative():
      sr0 = sr0.negate()
    if not isSquare:
      s = sr0
      c = r

    #pylint: disable=invalid-name
    Nt: FieldElement = (c * (r - ONE) * ((d - ONE) * (d - ONE))) - D
    #pylint: disable=invalid-name
    W0: FieldElement = FieldElement(2) * s * D
    #pylint: disable=invalid-name
    W1: FieldElement = Nt * SQRT_AD_MINUS_ONE
    #pylint: disable=invalid-name
    W2: FieldElement = ONE - (s * s)
    #pylint: disable=invalid-name
    W3: FieldElement = ONE + (s * s)
    #pylint: disable=invalid-name
    X: FieldElement = W0 * W3
    #pylint: disable=invalid-name
    Y: FieldElement = W2 * W1
    #pylint: disable=invalid-name
    Z: FieldElement = W1 * W3

    res.append(Point([X * Z.inv(), Y * Z.inv()]))

  return RistrettoPoint(res[0] + res[1])

class RistrettoScalar(
  Scalar
):
  def toPoint(
    self
  ) -> RistrettoPoint:
    return RistrettoPoint(Scalar.toPoint(self))

#pylint: disable=invalid-name
def Bint(
  m: bytes
) -> Scalar:
  return Scalar(hashlib.blake2b(m).digest())

#Aggregate Ristretto public keys for usage with MuSig.
def aggregate(
  keys: List[RistrettoPoint]
) -> RistrettoPoint:
  #Single key/no different keys.
  if len({key.serialize() for key in keys}) == 1:
    return keys[0]

  #pylint: disable=invalid-name
  L: bytes = b""
  for key in keys:
    L = L + key.serialize()
  L = hashlib.blake2b(L).digest()

  res: Point = keys[0].underlying * Bint(b"agg" + L + keys[0].serialize()).underlying
  for k in range(1, len(keys)):
    res = res + (keys[k].underlying * Bint(b"agg" + L + keys[k].serialize()).underlying)
  return RistrettoPoint(res)

#Called SigningKey for legacy reasons.
#Naming preserved due to conflict with BLS's PrivateKey.
class SigningKey:
  def __init__(
    self,
    seed: bytes
  ) -> None:
    esk: bytes = seed
    if len(seed) != 64:
      esk = hashlib.sha512(seed).digest()
    self.scalar: Scalar = Scalar(esk[:32])
    self.nonce: bytes = esk[32:]
    self.publicKey: bytes = RistrettoPoint(self.scalar.toPoint()).serialize()

  def sign(
    self,
    msg: bytes
  ) -> bytes:
    r: Scalar = Bint(self.nonce + msg)
    #pylint: disable=invalid-name
    R: bytes = RistrettoPoint(r.toPoint()).serialize()
    k: Scalar = Bint(R + self.publicKey + msg)
    return R + (r + (k * self.scalar)).serialize()

  def get_verifying_key(
    self
  ) -> bytes:
    return self.publicKey
