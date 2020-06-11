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

from pyfinite.ffield import FField

FIELD_BITS: int = 64
FIELD_BYTES: int = FIELD_BITS // 8
FIELD_MODULUS: int = (1 << FIELD_BITS) + 27

# TODO: Uset the following two functions?

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
  return b''.join(elem.to_bytes(FIELD_BYTES, 'little') for elem in odd_sums)

#A merge function is not provided as it's literally a xor of the two sketches.

# a^2 % f
def sqrMod(a, f):
  sqr = field.Multiply(a, a)
  _, rem = field.FullDivision(sqr, f, field.FindDegree(sqr), field.FindDegree(f))
  return rem

def setCoeff(
  field: FField,
  f: int,
  i: int,
  a: int
) -> int:
  degree: int = field.FindDegree(i)
  result: int = result | 1 << degree  # FIXME: Works only if the bit is zero
  #x.normalize();
  return result

def traceMap(a, f):
  res = a
  tmp = a

  for i in range(FIELD_BITS-1):
    tmp = sqrMod(tmp, f)
    res = field.Add(res, tmp)

  return res

def findRoots(field, f) -> List[int]:
  if field.FindDegree(f) == 0:
    return [0]

  if field.FindDegree(f) == 1:
    return f & 1
      
  while True:
    r = field.GetRandomElement()
    h = 0
    h = setCoeff(field, h, 1, r);
    h = traceMap(h, f);
    h, _, _ = field.ExtendedEuclid(h, f, field.FindDegree(h), field.FindDegree(f))
    if not (field.FindDegree(h) <= 0 or field.FindDegree(h) == field.FindDegree(f)):
      break

  roots = FindRoots(field, h)
  h = field.Divide(f, h)
  roots.extend(FindRoots(field, h))
  return roots

def decode_sketch(
  sketch: bytes,
  capacity: int
) -> List[int]:
  withoutEvens: int = 0
  for e in range(0, len(sketch), FIELD_BYTES):
    withoutEvens.append(int.from_bytes(sketch[e : e + FIELD_BYTES], 'little'))

  ss: List[int] = []
  for wE in withoutEvens:
    ss.append(wE)
    ss.append(mul(wE, wE))

  r1: int = 0
  r2: int = 0
  r3: int = 0
  v1: int = 0
  v2: int = 0
  v3: int = 0
  q: int = 0
  temp: int = 0

  # TODO: Don't introduce these vars
  Rold: int = 0
  Rcur: int = 0
  Rnew: int = 0
  Vold: int = 0
  Vcur: int = 0
  Vnew: int = 0
  tempPointer: int = 0

  Rold = r1
  Rcur = r2
  Rnew = r3

  Vold = v1
  Vcur = v2
  Vnew = v3

  field: FField = FField(FIELD_BITS)

  Rold = setCoeff(field, Rold, d-1, 1);  # Rold holds z^{d-1}

  # Rcur=S(z)/z where S is the syndrome poly, Rcur = \sum S_j z^{j-1}
  # Note that because we index arrays from 0, S_j is stored in ss[j-1]
  for i in range(d-1):
    Rcur = setCoeff(field, Rcur, i, ss[i]);

	# Vold is already 0 -- no need to initialize
	# Initialize Vcur to 1
  Vcur = setCoeff(field, Vcur, 0, 1) # Vcur = 1

  # TODO: Use Euclid from ffinite
	# Now run Euclid, but stop as soon as degree of Rcur drops below
	# (d-1)/2
	# This will take O(d^2) operations in GF(2^m)

  t: int = (d-1)//2

  while field.FindDegree(Rcur) >= t:
    # Rold = Rcur*q + Rnew
    q, Rnew = field.FullDivision(Rold, Rcur, field.FindDegree(Rold), field.FindDegree(Rcur))

    # Vnew = Vold - qVcur
    temp = field.Multiply(q, Vcur);
    Vnew = field.Subtract(Vold, temp);

    # swap everything (TODO: Simplify.)
    tempPointer = Rold
    Rold = Rcur
    Rcur = Rnew
    Rnew = tempPointer

    tempPointer = Vold
    Vold = Vcur
    Vcur = Vnew
    Vnew = tempPointer

	# At the end of the loop, sigma(z) is Vcur
	# (up to a constant factor, which doesn't matter,
	# since we care about roots of sigma).
	# The roots of sigma(z) are inverses of the points we
	# are interested in.  

  # find roots of sigma(z)
  # this will take O(e^2 + e^{\log_2 3} m) operations in GF(2^m),
  # where e is the degree of sigma(z)
  answer = findRoots(field, Vcur)

  # take inverses of roots of sigma(z)
  for v in answer:
    v = field.Inverse(v)

  return answer
