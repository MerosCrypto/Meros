"""
The following, FIELD_BITS, FIELD_MODULUS, mul2, mul, and create_sketch, are licensed as such:

MIT License

Copyright (c) 2019 Gleb Naumenko <naumenko.gs@gmail.com>, Pieter Wuille <pieter.wuille@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

from typing import List

FIELD_BITS: int = 64
FiELD_BYTES: int = FIELD_BITS // 8
FIELD_MODULUS: int = (1 << FIELD_BITS) + 0b10001101

def mul2(
  x: int
) -> int:
  """Compute 2*x in GF(2^FIELD_BITS)"""
  return (x << 1) ^ (FIELD_MODULUS if x.bit_length() >= FIELD_BITS else 0)

def mul(
  x: int,
  y: int
) -> int:
  """Compute x*y in GF(2^FIELD_BITS)"""
  ret: int = 0
  for bit in [(x >> i) & 1 for i in range(x.bit_length())]:
    ret, y = ret ^ bit * y, mul2(y)
  return ret

def create_sketch(
  shortids: List[int],
  capacity: int
) -> bytes:
  """Compute the bytes of a sketch for given shortids and given capacity."""
  odd_sums: List[int] = [0 for _ in range(capacity)]
  for shortid in shortids:
    squared: int = mul(shortid, shortid)
    for i in range(capacity):
      odd_sums[i] ^= shortid
      shortid = mul(shortid, squared)
  return b''.join(elem.to_bytes(FiELD_BYTES, 'little') for elem in odd_sums)

#A merge function is not provided as it's literally a xor of the two sketches.

def decode_sketch(
  sketch: bytes,
  capacity: int
) -> List[int]:
  return []
