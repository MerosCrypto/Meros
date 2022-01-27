#pylint: disable=invalid-name

from typing import List, Tuple
import hashlib

from gmpy2 import mpz

import e2e.Libs.Ristretto.Ristretto as Ristretto

HARDENED_THRESHOLD: int = 1 << 31

def deriveKeyAndChainCode(
  secret: bytes,
  path: List[int]
) -> Tuple[bytes, bytes]:
  if len(secret) != 64:
    raise Exception("Invalid length secret.")
  k: bytes = Ristretto.RistrettoScalar(secret).serialize()

  #Parent public key/chain code.
  A: bytes = Ristretto.RistrettoScalar(k).toPoint().serialize()
  c: bytes = hashlib.blake2b(b"ChainCode" + k, digest_size=32).digest()

  #Derive each child.
  for i in path:
    iBytes: bytes = i.to_bytes(4, "little")
    Z: bytes
    if i < HARDENED_THRESHOLD:
      Z = hashlib.blake2b(b"Key" + c + A + iBytes).digest()
      c = hashlib.blake2b(b"ChainCode" + c + A + iBytes, digest_size=32).digest()
    else:
      Z = hashlib.blake2b(b"Key" + c + k + iBytes).digest()
      c = hashlib.blake2b(b"ChainCode" + c + k + iBytes, digest_size=32).digest()

    scalar: Ristretto.Scalar = Ristretto.RistrettoScalar(k) + Ristretto.RistrettoScalar(Z)
    if scalar.underlying == mpz(0):
      raise Exception("Invalid child.")
    k = scalar.serialize()
    A = Ristretto.RistrettoPoint(scalar.toPoint()).serialize()

  return (k, c)

def derive(
  secret: bytes,
  path: List[int]
) -> bytes:
  key: bytes
  key, _ = deriveKeyAndChainCode(secret, path)
  return key
