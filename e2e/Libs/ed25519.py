#pylint: disable=invalid-name

from typing import List

import hashlib

b: int = 256
q: int = 2**255 - 19
l: int = 2**252 + 27742317777372353535851937790883648493

def H(
  m: bytes
) -> bytes:
  return hashlib.sha512(m).digest()

def expmod(
  bExp: int,
  e: int,
  m: int
) -> int:
  if e == 0:
    return 1
  t: int = (expmod(bExp, e // 2, m) ** 2) % m
  if e & 1:
    t = (t * bExp) % m
  return t

def inv(
  x: int
) -> int:
  return expmod(x, q - 2, q)

d: int = -121665 * inv(121666)
I: int = expmod(2, (q - 1) // 4, q)

def xrecover(
  y: int
) -> int:
  xx: int = ((y * y) - 1) * inv((d * y * y) + 1)
  x: int = expmod(xx, (q + 3) // 8, q)
  if (((x * x) - xx) % q) != 0:
    x = (x * I) % q
  if x % 2 != 0:
    x = q - x
  return x

By: int = 4 * inv(5)
Bx: int = xrecover(By)
B: List[int] = [Bx % q, By % q]

def edwards(
  P: List[int],
  Q: List[int]
):
  x1: int = P[0]
  y1: int = P[1]
  x2: int = Q[0]
  y2: int = Q[1]
  x3: int = ((x1 * y2) + (x2 * y1)) * inv(1 + (d * x1 * x2 * y1 * y2))
  y3: int = ((y1 * y2) + (x1 * x2)) * inv(1 - (d * x1 * x2 * y1 * y2))
  return [x3 % q, y3 % q]

def scalarmult(
  P: List[int],
  e: int
) -> List[int]:
  if e == 0:
    return [0, 1]
  Q: List[int] = scalarmult(P, e // 2)
  Q = edwards(Q, Q)
  if e & 1:
    #pylint: disable=arguments-out-of-order
    Q = edwards(Q, P)
  return Q

def encodeint(
  y: int
) -> bytes:
  return y.to_bytes(32, "little")

def encodepoint(
  P: List[int]
) -> bytes:
  res: bytearray = bytearray(P[1].to_bytes(32, "little"))
  res[-1] = (((res[-1] << 1) & 255) >> 1) | ((P[0] & 1) << 7)
  return bytes(res)

def bit(
  h: bytes,
  i: int
):
  return (h[i // 8] >> (i % 8)) & 1

def Hint(
  m: bytes
) -> int:
  return int.from_bytes(H(m), "little") % l

def sign(
  msg: bytes,
  secret: bytes
) -> bytes:
  s: int = int.from_bytes(secret[:32], "little")
  s &= (1 << 254) - 8
  s |= (1 << 254)
  prefix: bytes = secret[32:]

  A: bytes = encodepoint(scalarmult(B, s))
  r: int = Hint(prefix + msg)
  R: bytes = encodepoint(scalarmult(B, r))
  k: int = Hint(R + A + msg)
  s: int = (r + (k * s)) % l
  return R + int.to_bytes(s, 32, "little")

def isoncurve(
  P: List[int]
) -> bool:
  x: int = P[0]
  y: int = P[1]
  return ((-(x * x) + (y*y) - 1 - (d * x * x * y * y)) % q) == 0

def decodeint(
  s: bytes
) -> int:
  return sum(((2 ** i) * bit(s, i)) for i in range(0, b))

def decodepoint(
  s: bytes
) -> List[int]:
  y: int = sum(((2 ** i) * bit(s, i)) for i in range(0, b - 1))
  x: int = xrecover(y)
  if x & 1 != bit(s, b - 1):
    x = q - x
  P: List[int] = [x, y]
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
  R: List[int] = decodepoint(s[:(b // 8)])
  A: List[int] = decodepoint(pk)
  S: int = decodeint(s[(b // 8) : (b // 4)])
  h: int = Hint(encodepoint(R) + pk + m)
  return scalarmult(B, S) == edwards(R, scalarmult(A, h))
