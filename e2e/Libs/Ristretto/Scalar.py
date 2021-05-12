from typing import Union

#pylint: disable=no-name-in-module
from gmpy2 import mpz

from e2e.Libs.Ristretto.Point import Point, BASEPOINT

l: mpz = mpz(2**252 + 27742317777372353535851937790883648493)

class Scalar:
  underlying: mpz

  def __init__(
    self,
    scalar: Union[mpz, int, bytes, bytearray]
  ) -> None:
    if isinstance(scalar, bytearray):
      scalar = bytes(scalar)
    if isinstance(scalar, bytes):
      self.underlying = mpz(int.from_bytes(scalar, "little"))
    elif isinstance(scalar, int):
      self.underlying = mpz(scalar)
    else:
      self.underlying = scalar
    self.underlying = self.underlying % l

  def __add__(
    self,
    other: 'Scalar'
  ) -> 'Scalar':
    return Scalar(self.underlying + other.underlying)

  def __mul__(
    self,
    scalar: 'Scalar'
  ) -> 'Scalar':
    return Scalar(self.underlying * scalar.underlying)

  def toPoint(
    self
  ) -> Point:
    return BASEPOINT * self.underlying

  def serialize(
    self
  ) -> bytes:
    return int(self.underlying).to_bytes(32, "little")

MODULUS: Scalar = Scalar(l)
