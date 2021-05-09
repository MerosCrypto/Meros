#Wrapper around the reference implementation of ed25519 with an API matching https://pypi.org/project/ed25519/.
#The file is named ed25519 for the same reason.
#pylint: disable=invalid-name

from typing import List, Union
import hashlib

#pylint: disable=no-name-in-module,c-extension-no-member
import gmpy2
from gmpy2 import mpz

from e2e.Libs.Ristretto.Point import Point as Ed25519Point, BASEPOINT
from e2e.Libs.Ristretto.Scalar import Scalar as Ed25519Scalar, MODULUS

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

  res: Ed25519Point = keys[0] * Bint(b"agg" + L + keys[0].serialize()).underlying
  for k in range(1, len(keys)):
    res = res + (keys[k] * Bint(b"agg" + L + keys[k].serialize()).underlying)
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
    self.publicKey: bytes = self.scalar.toPoint().serialize()

  def sign(
    self,
    msg: bytes
  ) -> bytes:
    r: Ed25519Scalar = Hint(self.nonce + msg)
    R: bytes = r.toPoint().serialize()
    k: Ed25519Scalar = Hint(R + self.publicKey + msg)
    return R + (r + (k * self.scalar)).serialize()

  def get_verifying_key(
    self
  ) -> bytes:
    return self.publicKey
