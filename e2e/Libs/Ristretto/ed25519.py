#Wrapper around the reference implementation of ed25519 with an API matching https://pypi.org/project/ed25519/.
#The file is named ed25519 for the same reason.
#pylint: disable=invalid-name

from typing import List, Union
import hashlib

#pylint: disable=no-name-in-module,c-extension-no-member
import gmpy2
from gmpy2 import mpz

import e2e.Libs.Ristretto.Ed25519Reference as ed

class Ed25519Point:
  underlying: List[mpz]

  def __init__(
    self,
    point: Union[List[mpz], bytes]
  ) -> None:
    if isinstance(point, bytes):
      self.underlying = ed.decodepoint(point)
    else:
      self.underlying = point

  def __add__(
    self,
    other: 'Ed25519Point'
  ) -> 'Ed25519Point':
    x1: mpz = self.underlying[0]
    y1: mpz = self.underlying[1]
    x2: mpz = other.underlying[0]
    y2: mpz = other.underlying[1]
    x3: mpz = ((x1 * y2) + (x2 * y1)) * ed.inv(ed.ONE + (ed.d * x1 * x2 * y1 * y2))
    y3: mpz = ((y1 * y2) + (x1 * x2)) * ed.inv(ed.ONE - (ed.d * x1 * x2 * y1 * y2))
    return Ed25519Point([x3 % ed.q, y3 % ed.q])

  def __mul__(
    self,
    scalar: 'Ed25519Scalar'
  ) -> 'Ed25519Point':
    if scalar.underlying == ed.ZERO:
      return Ed25519Point([ed.ZERO, ed.ONE])
    res: Ed25519Point = self * Ed25519Scalar(scalar.underlying // ed.TWO)
    res = res + res
    if scalar.underlying & ed.ONE:
      #pylint: disable=arguments-out-of-order
      res = res + self
    return res

  def serialize(
    self
  ) -> bytes:
    res: bytearray = bytearray(gmpy2.to_binary(self.underlying[1])[2:].ljust(32, b"\0"))
    res[-1] = (((res[-1] << 1) & 255) >> 1) | ((int(self.underlying[0]) & 1) << 7)
    return bytes(res)

BASEPOINT: Ed25519Point = Ed25519Point(ed.B)

class Ed25519Scalar:
  underlying: mpz

  def __init__(
    self,
    scalar: Union[mpz, int, bytes, bytearray]
  ) -> None:
    if isinstance(scalar, bytearray):
      scalar = bytes(scalar)
    if isinstance(scalar, bytes):
      self.underlying = gmpy2.from_binary(b"\1\1" + scalar)
    elif isinstance(scalar, int):
      self.underlying = mpz(scalar)
    else:
      self.underlying = scalar
    self.underlying = self.underlying % ed.l

  def serialize(
    self
  ) -> bytes:
    return gmpy2.to_binary(self.underlying)[2:].ljust(32, b"\0")

  def __add__(
    self,
    other: 'Ed25519Scalar'
  ) -> 'Ed25519Scalar':
    return Ed25519Scalar(self.underlying + other.underlying)

  def __mul__(
    self,
    scalar: 'Ed25519Scalar'
  ) -> 'Ed25519Scalar':
    return Ed25519Scalar(self.underlying * scalar.underlying)

  def toPoint(
    self
  ) -> Ed25519Point:
    return BASEPOINT * self

MODULUS: Ed25519Scalar = Ed25519Scalar(ed.l)

def Hint(
  m: bytes
) -> Ed25519Scalar:
  return Ed25519Scalar(hashlib.sha512(m).digest())

def Bint(
  m: bytes
) -> Ed25519Scalar:
  return Ed25519Scalar(hashlib.blake2b(m).digest())

#Aggregate Ed25519 public keys for usage with MuSig.
def aggregate(
  keys: List[Ed25519Point]
) -> Ed25519Point:
  #Single key/no different keys.
  if len({key.serialize() for key in keys}) == 1:
    return keys[0]

  L: bytes = b""
  for key in keys:
    L = L + key.serialize()
  L = hashlib.blake2b(L).digest()

  res: Ed25519Point = keys[0] * Bint(b"agg" + L + keys[0].serialize())
  for k in range(1, len(keys)):
    res = res + (keys[k] * Bint(b"agg" + L + keys[k].serialize()))
  return res

def seedToExtendedKey(
  seed: bytes
) -> bytes:
  esk: bytearray = bytearray(hashlib.sha512(seed).digest())
  esk[0] = esk[0] & 248
  esk[31] = esk[31] & 127
  esk[31] = esk[31] | 64
  return esk

#Called SigningKey for legacy reasons.
#Naming preserved due to conflict with BLS's PrivateKey.
class SigningKey:
  def __init__(
    self,
    seed: bytes
  ) -> None:
    esk: bytes = seed
    if len(seed) != 64:
      esk = seedToExtendedKey(seed)
    self.scalar: Ed25519Scalar = Ed25519Scalar(esk[:32])
    self.nonce: bytes = esk[32:]
    self.publicKey: bytes = (BASEPOINT * self.scalar).serialize()

  def sign(
    self,
    msg: bytes
  ) -> bytes:
    r: Ed25519Scalar = Hint(self.nonce + msg)
    R: bytes = (BASEPOINT * r).serialize()
    k: Ed25519Scalar = Hint(R + self.publicKey + msg)
    return R + (r + (k * self.scalar)).serialize()

  def get_verifying_key(
    self
  ) -> bytes:
    return self.publicKey
