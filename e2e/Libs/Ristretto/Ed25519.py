#Wrapper around the reference implementation of ed25519 with an API matching https://pypi.org/project/ed25519/.

#pylint: disable=no-name-in-module
from gmpy2 import mpz

import e2e.Libs.ed25519 as ed

#pylint: disable=too-few-public-methods
class VerifyingKey:
  def __init__(
    self,
    key: bytes
  ) -> None:
    self.key: bytes = key

  def to_bytes(
    self
  ) -> bytes:
    return self.key

class SigningKey:
  def __init__(
    self,
    seed: bytes
  ) -> None:
    key: bytearray = bytearray(ed.H(seed))
    key[0] = key[0] & 248
    key[31] = key[31] & 127
    key[31] = key[31] | 64
    self.seed: bytes = seed
    self.sk: mpz = ed.decodeint(key[:32]) % ed.l

  def sign(
    self,
    msg: bytes
  ) -> bytes:
    esk: bytearray = bytearray(ed.H(self.seed))
    esk[0] = esk[0] & 248
    esk[31] = esk[31] & 127
    esk[31] = esk[31] | 64
    return ed.sign(msg, bytes(esk))

  def get_verifying_key(
    self
  ) -> VerifyingKey:
    return VerifyingKey(ed.encodepoint(ed.scalarmult(ed.B, self.sk)))
