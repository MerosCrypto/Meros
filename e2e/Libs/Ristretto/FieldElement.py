from typing import Union

#pylint: disable=no-name-in-module
import gmpy2
from gmpy2 import mpz

ZERO: mpz = mpz(0)
ONE: mpz = mpz(1)
TWO: mpz = mpz(2)
THREE: mpz = mpz(3)
FOUR: mpz = mpz(4)
EIGHT: mpz = mpz(8)

q: mpz = mpz(2**255 - 19)

#This should inherit from hashToCurve's FieldElement as we already have a fully defined type.
#Will also enable moving this into that library.
class FieldElement:
  underlying: mpz

  def __init__(
    self,
    value: Union[mpz, int]
  ) -> None:
    if isinstance(value, int):
      value = mpz(value)
    self.underlying = (value + q) % q

  def __add__(
    self,
    other: "FieldElement"
  ) -> "FieldElement":
    return FieldElement(self.underlying + other.underlying)

  def __mul__(
    self,
    other: "FieldElement"
  ) -> "FieldElement":
    return FieldElement(self.underlying * other.underlying)

  def __sub__(
    self,
    other: "FieldElement"
  ) -> "FieldElement":
    return FieldElement(self.underlying - other.underlying)

  def isNegative(
    self
  ) -> bool:
    return (self.underlying & ONE) == ONE

  def negate(
    self
  ) -> "FieldElement":
    return FieldElement(ZERO - self.underlying)

  def __floordiv__(
    self,
    other: mpz
  ) -> "FieldElement":
    return FieldElement(self.underlying // other)

  def __mod__(
    self,
    other: mpz
  ) -> mpz:
    return self.underlying % other

  def __pow__(
    self,
    other: mpz
  ) -> "FieldElement":
    return FieldElement(gmpy2.powmod(self.underlying, other, q))

  def __eq__(
    self,
    other: "FieldElement"
  ) -> bool:
    return self.underlying == other.underlying

  def inv(
    self
  ) -> "FieldElement":
    return self ** (q - TWO)

  #Used to generate the Ed25519/Ristretto basepoint.
  def recoverX(
    self
  ) -> "FieldElement":
    #Uses d which is defined below.
    #pylint: disable=invalid-name
    I: FieldElement = FieldElement(TWO) ** ((q - ONE) // FOUR)

    y2: FieldElement = self * self
    xx: FieldElement = (y2 - FieldElement(ONE)) * ((d * y2) + FieldElement(ONE)).inv()
    x: FieldElement = xx ** ((q + THREE) // EIGHT)
    if ((x * x) - xx).underlying != ZERO:
      x = x * I
    if x.isNegative():
      x = x.negate()
    return x

d: FieldElement = FieldElement(-121665) * FieldElement(121666).inv()
