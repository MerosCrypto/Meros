#pylint: disable=invalid-name

#Reference implementation of ed25519 modernized and modified to use gmp.
#~3x faster using gmp.
#-75x slower that PyPi's ed25519, which wraps Supercop, and is reportedly ~20x slower than PyNaCL.

from typing import List

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

def bit(
  h: bytes,
  i: int
) -> int:
  return (h[i // 8] >> (i % 8)) & 1

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
