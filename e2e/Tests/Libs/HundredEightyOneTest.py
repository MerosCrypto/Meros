from typing import List
from ctypes import c_uint64

from random import getrandbits

from e2e.Libs.Minisketch import MinisketchLib, Sketch

def HundredEightyOneTest() -> None:
  for _ in range(100):
    capacity: int = getrandbits(7) + 1
    sketch1: Sketch = Sketch(capacity)
    sketch2: Sketch = Sketch(capacity)
    differences: List[int] = []

    for _ in range(capacity + getrandbits(7)):
      sketch1.hashes.append(getrandbits(64))
      MinisketchLib.minisketch_add_uint64(sketch1.sketch, c_uint64(sketch1.hashes[-1]))

      if (getrandbits(2) == 0) and (len(differences) < capacity):
        differences.append(sketch1.hashes[-1])
      else:
        sketch2.hashes.append(sketch1.hashes[-1])
        MinisketchLib.minisketch_add_uint64(sketch2.sketch, c_uint64(sketch2.hashes[-1]))

    sketch2.merge(sketch1.serialize())
    if sorted(differences) != sketch2.decode():
      raise Exception("")

HundredEightyOneTest()
