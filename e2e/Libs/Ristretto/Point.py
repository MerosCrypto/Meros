from typing import List, Union

#pylint: disable=no-name-in-module,c-extension-no-member
import gmpy2
from gmpy2 import mpz

ZERO: mpz = mpz(0)
ONE: mpz = mpz(1)
TWO: mpz = mpz(2)
THREE: mpz = mpz(3)
FIVE: mpz = mpz(5)
FOUR: mpz = mpz(4)
EIGHT: mpz = mpz(8)

q: mpz = mpz(2**255 - 19)

def expmod(
  bExp: mpz,
  e: mpz
) -> mpz:
  return gmpy2.powmod(bExp, e, q)

def inv(
  x: mpz
) -> mpz:
  return expmod(x, q - TWO)

d: mpz = mpz(-121665) * inv(mpz(121666))
I: mpz = expmod(TWO, (q - ONE) // FOUR)

def xrecover(
  y: mpz
) -> mpz:
  xx: mpz = ((y * y) - ONE) * inv((d * y * y) + ONE)
  x: mpz = expmod(xx, (q + THREE) // EIGHT)
  if (((x * x) - xx) % q) != ZERO:
    x = (x * I) % q
  if x % TWO != ZERO:
    x = q - x
  return x

By: mpz = FOUR * inv(FIVE)
Bx: mpz = xrecover(By)
B: List[mpz] = [Bx % q, By % q]

class Point:
  underlying: List[mpz]

  def __init__(
    self,
    point: List[mpz]
  ) -> None:
    self.underlying = point

  def __add__(
    self,
    other: 'Point'
  ) -> 'Point':
    x1: mpz = self.underlying[0]
    y1: mpz = self.underlying[1]
    x2: mpz = other.underlying[0]
    y2: mpz = other.underlying[1]
    x3: mpz = ((x1 * y2) + (x2 * y1)) * inv(ONE + (d * x1 * x2 * y1 * y2))
    y3: mpz = ((y1 * y2) + (x1 * x2)) * inv(ONE - (d * x1 * x2 * y1 * y2))
    return Point([x3 % q, y3 % q])

  def __mul__(
    self,
    scalar: mpz
  ) -> 'Point':
    if scalar == ZERO:
      return Point([ZERO, ONE])
    res: Point = self * (scalar // TWO)
    res = res + res
    if scalar & ONE:
      #pylint: disable=arguments-out-of-order
      res = res + self
    return res

  def serialize(
    self
  ) -> bytes:
    res: bytearray = bytearray(gmpy2.to_binary(self.underlying[1])[2:].ljust(32, b"\0"))
    res[-1] = (((res[-1] << 1) & 255) >> 1) | ((int(self.underlying[0]) & 1) << 7)
    return bytes(res)

BASEPOINT: Point = Point(B)
