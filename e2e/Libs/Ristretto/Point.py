from typing import List

#pylint: disable=no-name-in-module
from gmpy2 import mpz

from e2e.Libs.Ristretto.FieldElement import FieldElement, d

ZERO: mpz = mpz(0)
ONE: FieldElement = FieldElement(1)
TWO: mpz = mpz(2)

By: FieldElement = FieldElement(4) * FieldElement(5).inv()
B: List[FieldElement] = [By.recoverX(), By]

#See FieldElement's comments.
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

BASEPOINT: Point = Point(B)
