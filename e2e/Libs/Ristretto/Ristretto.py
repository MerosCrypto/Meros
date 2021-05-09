from typing import List, Tuple, Union

from gmpy2 import mpz

from e2e.Libs.Ristretto.FieldElement import FieldElement, q, d
from e2e.Libs.Ristretto.Scalar import Scalar
from e2e.Libs.Ristretto.Point import Point

#TODO: How was this calculated?
SQRT_M1: FieldElement = FieldElement(19681161376707505956807079304988542015446066515923890162744021073123829784752)
INVSQRT_A_MINUS_D: FieldElement = FieldElement(54469307008909316920995813868745141605393597292927456921205312896311721017578)

def invSqrRoot(
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

class RistrettoScalar(
  Scalar
):
  ...

class RistrettoPoint:
  underlying: Point

  def serialize(
    self
  ) -> bytes:
    X: FieldElement = self.underlying.underlying[0]
    Y: FieldElement = self.underlying.underlying[1]
    Z: FieldElement = FieldElement(1)
    T: FieldElement = X * Y

    u1: FieldElement = (Z + Y) * (Z - Y)
    u2: FieldElement = T
    root: Tuple[bool, FieldElement] = invSqrRoot(FieldElement(1), u1 * u2 * u2)
    I: FieldElement = root[1]

    D1: FieldElement = u1 * I
    D2: FieldElement = u2 * I

    Zinv: FieldElement = D1 * D2 * T

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
      I: FieldElement
      (root, I) = invSqrRoot(FieldElement(1), v * u2 * u2)
      if not root:
        raise Exception("Point doesn't have a root.")
      Dx: FieldElement = I * u2
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
    scalar: RistrettoScalar
  ) -> 'RistrettoPoint':
    return RistrettoPoint(self.underlying * scalar.underlying)

  def __eq__(
    self,
    other: 'RistrettoPoint'
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

def hashToCurve(
  message: bytes
) -> RistrettoPoint:
  raise Exception("Not implemented.")
