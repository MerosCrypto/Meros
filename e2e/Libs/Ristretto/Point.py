from typing import List, Union

from gmpy2 import mpz

from e2e.Libs.Ristretto.FieldElement import FieldElement, d

ZERO: mpz = mpz(0)
ONE: FieldElement = FieldElement(1)
TWO: mpz = mpz(2)

By: FieldElement = FieldElement(4) * FieldElement(5).inv()
B: List[FieldElement] = [By.recoverX(), By]

class Point:
  underlying: List[FieldElement]

  def __init__(
    self,
    point: List[FieldElement]
  ) -> None:
    self.underlying = point

  def __add__(
    self,
    other: 'Point'
  ) -> 'Point':
    x1: FieldElement = self.underlying[0]
    y1: FieldElement = self.underlying[1]
    x2: FieldElement = other.underlying[0]
    y2: FieldElement = other.underlying[1]

    xs: FieldElement = x1 * x2
    ys: FieldElement = y1 * y2
    product: FieldElement = d * xs * ys

    x3: FieldElement = ((x1 * y2) + (x2 * y1)) * (ONE + product).inv()
    y3: FieldElement = (ys + xs) * (ONE - product).inv()
    return Point([x3, y3])

  def __mul__(
    self,
    scalar: mpz
  ) -> 'Point':
    if scalar == ZERO:
      return Point([FieldElement(ZERO), ONE])
    res: Point = self * (scalar // TWO)
    res = res + res
    if scalar & mpz(1):
      #pylint: disable=arguments-out-of-order
      res = res + self
    return res

  #TODO: remove this.
  def serialize(
    self
  ) -> bytes:
    #res: bytearray = bytearray(gmpy2.to_binary(self.underlying[1].underlying)[2:].ljust(32, b"\0"))
    #res[-1] = (((res[-1] << 1) & 255) >> 1) | ((int(self.underlying[0].underlying) & 1) << 7)
    return bytes(32)

BASEPOINT: Point = Point(B)
