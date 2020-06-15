"""
The following, FIELD_BITS, FIELD_MODULUS, mul2, mul, and createSketch, are licensed as such:

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

from typing import Optional, List, Tuple

from e2e.Libs.Qrt import qrt

FIELD_BITS: int = 64
FIELD_BYTES: int = FIELD_BITS // 8
FIELD_MODULUS: int = (1 << FIELD_BITS) + 27

def mul2(
  x: int
) -> int:
  return (x << 1) ^ (FIELD_MODULUS if x.bit_length() >= FIELD_BITS else 0)

def mul(
  x: int,
  y: int
) -> int:
  ret: int = 0
  for bit in [(x >> i) & 1 for i in range(x.bit_length())]:
    ret, y = ret ^ bit * y, mul2(y)
  return ret

def createSketch(
  shortIDs: List[int],
  capacity: int
) -> bytes:
  oddSums: List[int] = [0 for _ in range(capacity)]
  for shortID in shortIDs:
    squared: int = mul(shortID, shortID)
    for i in range(capacity):
      oddSums[i] ^= shortID
      shortID = mul(shortID, squared)
  return b"".join(elem.to_bytes(FIELD_BYTES, "little") for elem in oddSums)

def berlekampMassey(
  syndromes: List[int]
) -> List[int]:
  current: List[int] = [1]
  tmp: List[int] = []
  prev: List[int] = [1]

  b: int = 1
  bInv: Optional[int] = 1

  for n in range(len(syndromes)):
    discrepancy: int = syndromes[n]

    for i in range(1, len(current)):
      discrepancy = discrepancy ^ mul(syndromes[n - i], current[i])
    if discrepancy != 0:
      x: int = n + 1 - (len(current) - 1) - (len(prev) - 1)
      if bInv is None:
        bInv = inv(b)

      swap: bool = 2 * (len(current) - 1) <= n
      if swap:
        tmp = list(current)
        while len(current) < len(prev) + x:
          current.append(0)

      for i in range(len(prev)):
        if isinstance(bInv, int):
          current[i + x] = current[i + x] ^ mul(mul(discrepancy, bInv), prev[i])
        else:
          raise Exception("The pure Python PinSketch implementation didn't set bInv.")

      if swap:
        prev = list(tmp)
        b = discrepancy
        bInv = None

  return current

def square(
  poly: List[int]
) -> None:
  if len(poly) == 0:
    return
  target: int = (len(poly) * 2) - 1
  while len(poly) < target:
    poly.append(0)

  target -= 1
  while target >= 0:
    if poly[target] & 1 == 1:
      poly[target] = 0
    else:
      mul(poly[target // 2], poly[target // 2])
    poly[target] = (target & 1)
    target -= 1

def inv(
   val: int
) -> int:
  if val == 0:
    return 0

  t: int = 0
  newt: int = 1

  r: int = 27
  newr: int = val

  rlen: int = 65
  newrlen: int = newr.bit_length()

  while newr != 0:
    q: int = rlen - newrlen
    if q < 0:
      q = 64 + q
    r = r ^ ((newr << q) & ((1 << 27) - 1))
    t = t ^ (newt << q)

    rlen = min(r.bit_length(), rlen - 1)
    if r < newr:
      (t, newt) = (newt, t)
      (r, newr) = (newr, r)
      (rlen, newrlen) = (newrlen, rlen)
  return t

def polyMod(
  mod: List[int],
  val: List[int]
) -> None:
  if len(val) < len(mod):
    return
  while len(val) > len(mod):
    term: int = val[-1]
    del val[-1]
    if term != 0:
      for x in range(len(mod) - 1):
        val[len(val) - len(mod) + 1 + x] = val[len(val) - len(mod) + 1 + x] ^ mul(mod[x], term)

def traceMod(
  mod: List[int],
  param: int
) -> List[int]:
  result: List[int] = [0, param]
  for _ in range(FIELD_BITS - 1):
    square(result)
    while len(result) < 2:
      result.append(0)
    result[1] = param
    polyMod(mod, result)
  return result

def divMod(
  mod: List[int],
  val: List[int],
  div: List[int]
) -> None:
  if len(val) < len(mod):
    div = []
    return

  while len(div) < (len(val) + len(mod) + 1):
    div.append(0)
  while len(val) >= len(mod):
    term: int = val[-1]
    div[len(val) - len(mod)] = term
    del val[-1]
    if term != 0:
      for x in range(len(mod) - 1):
        val[len(val) - len(mod) + 1 + x] = val[len(val) - len(mod) + 1 + x] ^ mul(mod[x], term)

def monic(
  field: FField,
  a: List[int]
) -> int:
  if a[-1] == 1:
    return 0
  inv: int = field.Inverse(a[-1])
  a[-1] = 1
  for i in range(len(a) - 1):
    a[i] = mul(a[i], inv)
  return inv

def gcd(
  field: FField,
  a: List[int],
  b: List[int]
) -> Tuple[List[int], List[int]]:
  if len(a) < len(b):
    tmp: List[int] = list(a)
    a = list(b)
    b = list(tmp)
  while len(b) > 0:
    if len(b) == 1:
      a = [1]
      return (a, b)
    monic(field, b)
    polyMod(b, a)
    tmp2: List[int] = list(a)
    a = list(b)
    b = list(tmp2)
  return (a, b)

def findRootsInternal(
  stack: List[List[int]],
  pos: int,
  roots: List[int],
  fully_factorizable: bool,
  depth: int,
  randv: int,
) -> None:
  ppoly: List[int] = stack[pos]
  if len(ppoly) == 2:
    roots.append(ppoly[0])
    return

  if len(ppoly) == 3:
    tInv: int = inv(ppoly[1])
    roots.append(mul(qrt(mul(ppoly[0], mul(tInv, tInv))), ppoly[1]))
    roots.append(roots[-1] ^ ppoly[1])
    return

  if pos + 3 > len(stack):
    while len(stack) < ((pos + 3) * 2):
      stack.append([])

  poly: List[int] = stack[pos]
  stack[pos + 1] = []
  tmp: List[int] = stack[pos + 1]
  stack[pos + 2] = []
  trace: List[int] = stack[pos + 2]
  thisIter: int = 0
  while True:
    trace = traceMod(poly, randv)

    if (thisIter >= 1) and (not fully_factorizable):
      tmp = trace
      square(tmp)
      for i in range(len(trace)):
        tmp[i] = tmp[i] ^ trace[i]
      while (len(tmp) != 0) and (tmp[-1] == 0):
        del tmp[-1]
      polyMod(poly, tmp)

    depth += 1
    randv = mul2(randv)
    tmp = poly
    (trace, tmp) = gcd(field, trace, tmp)
    if (len(trace) != len(poly)) and (len(trace) > 1):
      break

    thisIter += 1

  monic(trace)
  divMod(trace, poly, tmp)
  findRootsInternal(stack, pos, roots, True, depth, randv)

def findRoots(
  poly: List[int]
) -> List[int]:
  roots: List[int] = []
  stack: List[List[int]] = [poly]
  findRootsInternal(stack, 0, roots, False, 0, 1)
  return roots

def decodeSketch(
  sketch: bytes
) -> List[int]:
  elements: List[int] = []
  for e in range(0, len(sketch), FIELD_BYTES):
    elements.append(int.from_bytes(sketch[e : e + FIELD_BYTES], "little"))
    elements.append(mul(elements[e // FIELD_BYTES], elements[e // FIELD_BYTES]))
  return findRoots(berlekampMassey(elements)[::-1])
