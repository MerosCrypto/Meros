#pylint: disable=invalid-name

#Reference implementation of ed25519.

from typing import List
import hashlib

import gmpy2
#pylint: disable=no-name-in-module,c-extension-no-member
from gmpy2 import mpz

ZERO: mpz = mpz(0)
ONE: mpz = mpz(1)
TWO: mpz = mpz(2)
THREE: mpz = mpz(3)
FOUR: mpz = mpz(4)
FIVE: mpz = mpz(5)
EIGHT: mpz = mpz(8)

b: int = 256
q: mpz = mpz(2**255 - 19)
l: mpz = mpz(2**252 + 27742317777372353535851937790883648493)

def H(
  m: bytes
) -> bytes:
  return hashlib.sha512(m).digest()

def expmod(
  bExp: mpz,
  e: mpz,
  m: mpz
) -> mpz:
  if e == ZERO:
    return ONE
  t: mpz = (expmod(bExp, e // TWO, m) ** TWO) % m
  if e & ONE:
    t = (t * bExp) % m
  return t

def inv(
  x: mpz
) -> mpz:
  return expmod(x, q - TWO, q)

d: mpz = mpz(-121665) * inv(mpz(121666))
I: mpz = expmod(TWO, (q - ONE) // FOUR, q)

def xrecover(
  y: mpz
) -> mpz:
  xx: mpz = ((y * y) - ONE) * inv((d * y * y) + ONE)
  x: mpz = expmod(xx, (q + THREE) // EIGHT, q)
  if (((x * x) - xx) % q) != ZERO:
    x = (x * I) % q
  if x % TWO != ZERO:
    x = q - x
  return x

By: mpz = FOUR * inv(FIVE)
Bx: mpz = xrecover(By)
B: List[mpz] = [Bx % q, By % q]

def edwards(
  P: List[mpz],
  Q: List[mpz]
):
  x1: mpz = P[0]
  y1: mpz = P[1]
  x2: mpz = Q[0]
  y2: mpz = Q[1]
  x3: mpz = ((x1 * y2) + (x2 * y1)) * inv(ONE + (d * x1 * x2 * y1 * y2))
  y3: mpz = ((y1 * y2) + (x1 * x2)) * inv(ONE - (d * x1 * x2 * y1 * y2))
  return [x3 % q, y3 % q]

def scalarmult(
  P: List[mpz],
  e: mpz
) -> List[mpz]:
  if e == 0:
    return [ZERO, ONE]
  Q: List[mpz] = scalarmult(P, e // TWO)
  Q = edwards(Q, Q)
  if e & ONE:
    #pylint: disable=arguments-out-of-order
    Q = edwards(Q, P)
  return Q

def encodeint(
  y: mpz
) -> bytes:
  return gmpy2.to_binary(y)[2:].ljust(32, b"\0")

def encodepoint(
  P: List[mpz]
) -> bytes:
  res: bytearray = bytearray(encodeint(P[1]))
  res[-1] = (((res[-1] << 1) & 255) >> 1) | ((int(P[0]) & 1) << 7)
  return bytes(res)

def bit(
  h: bytes,
  i: int
) -> int:
  return (h[i // 8] >> (i % 8)) & 1

def decodeint(
  s: bytes
) -> mpz:
  return gmpy2.from_binary(b"\1\1" + s)

def Hint(
  m: bytes
) -> mpz:
  return decodeint(H(m)) % l

def Bint(
  m: bytes
) -> mpz:
  return decodeint(hashlib.blake2b(m).digest()) % l

def sign(
  msg: bytes,
  secret: bytes
) -> bytes:
  s: mpz = decodeint(secret[:32])
  s &= (ONE << 254) - EIGHT
  s |= (ONE << 254)
  prefix: bytes = secret[32:]

  A: bytes = encodepoint(scalarmult(B, s))
  r: mpz = Hint(prefix + msg)
  R: bytes = encodepoint(scalarmult(B, r))
  k: mpz = Hint(R + A + msg)
  s: mpz = (r + (k * s)) % l
  return R + encodeint(s)

def isoncurve(
  P: List[mpz]
) -> bool:
  x: mpz = P[0]
  y: mpz = P[1]
  return ((ZERO - (x * x) + (y*y) - ONE - (d * x * x * y * y)) % q) == ZERO

def decodepoint(
  s: bytes
) -> List[mpz]:
  y: mpz = mpz(sum(((2 ** i) * bit(s, i)) for i in range(0, b - 1)))
  x: mpz = xrecover(y)
  if (x & ONE) != bit(s, b - 1):
    x = q - x
  P: List[mpz] = [x, y]
  if not isoncurve(P):
    raise Exception("decoding point that is not on curve")
  return P

def verify(
  s: bytes,
  m: bytes,
  pk: bytes
) -> bool:
  if len(s) != b // 4:
    return False
  if len(pk) != b // 8:
    return False
  R: List[mpz] = decodepoint(s[:(b // 8)])
  A: List[mpz] = decodepoint(pk)
  S: mpz = decodeint(s[(b // 8) : (b // 4)])
  h: mpz = Hint(encodepoint(R) + pk + m)
  return scalarmult(B, S) == edwards(R, scalarmult(A, h))

#Aggregate Ed25519 public keys for usage with MuSig.
def aggregate(
  keys: List[bytes]
) -> bytes:
  #Single key/no different keys.
  if len(set(keys)) == 1:
    return keys[0]

  L: bytes = b""
  for key in keys:
    L = L + key
  L = hashlib.blake2b(L).digest()

  res: List[mpz] = []
  for key in keys:
    if len(res) == 0:
      res = scalarmult(decodepoint(key), Bint(b"agg" + L + key))
    else:
      res = edwards(res, scalarmult(decodepoint(key), Bint(b"agg" + L + key)))
  return encodepoint(res)
