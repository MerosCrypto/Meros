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

def setCoeff(
  x: List[int],
  i: int,
  a: int
) -> None:
  if a != 0:  # TODO: necessary to check this?
    x[i] = a

def deg(x: List[int]):
  return len(x) - 1

def decode_sketch(
  sketch: bytes,
  capacity: int
) -> List[int]:
  withoutEvens: List[int] = []
  for e in range(0, len(sketch), FIELD_BYTES):
    withoutEvens.append(int.from_bytes(sketch[e : e + FIELD_BYTES], 'little'))

  ss: List[int] = []
  for wE in withoutEvens:
    ss.append(wE)
    ss.append(mul(wE, wE))

	r1: List[int] = []
  r2: List[int] = []
  r3: List[int] = []
  v1: List[int] = []
  v2: List[int] = []
  v3: List[int] = []
  q: List[int] = []
  temp: List[int] = []
  
  # TODO: Don't introduce these vars
	Rold: List[int] = []
  Rcur: List[int] = []
  Rnew: List[int] = []
  Vold: List[int] = []
  Vcur: List[int] = []
  Vnew: List[int] = []
  tempPointer: List[int] = []

	Rold = r1
	Rcur = r2
	Rnew = r3

	Vold = v1
	Vcur = v2
	Vnew = v3

  # field: FField = FField(FIELD_BITS)

  setCoeff(Rold, d-1, 1);  # Rold holds z^{d-1}

	# Rcur=S(z)/z where S is the syndrome poly, Rcur = \sum S_j z^{j-1}
  # Note that because we index arrays from 0, S_j is stored in ss[j-1]
	for i in range(d-1):
	  setCoeff(Rcur, i, ss[i]);

	# Vold is already 0 -- no need to initialize
	# Initialize Vcur to 1
	setCoeff(Vcur, 0, 1); // Vcur = 1

	# Now run Euclid, but stop as soon as degree of Rcur drops below
	# (d-1)/2
	# This will take O(d^2) operations in GF(2^m)

	t: int = (d-1)//2;

	while deg(Rcur) >= t:
	  # Rold = Rcur*q + Rnew
	  DivRem(q, *Rnew, *Rold, *Rcur);

	  // Vnew = Vold - qVcur)
	  mul(temp, q, *Vcur);
	  sub (*Vnew, *Vold, temp);


          // swap everything
	  tempPointer = Rold;	
	  Rold = Rcur;
	  Rcur = Rnew;
	  Rnew = tempPointer;

	  tempPointer = Vold;
	  Vold = Vcur;
	  Vcur = Vnew;
	  Vnew = tempPointer;


  #########################################################

  #While the following setCoeff call is required, it shouldn't be returned.
  #It's used to calculate what should be returned.
  return [setCoeff(field, capacity * 2)]
