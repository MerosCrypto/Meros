from typing import List
from ctypes import c_uint64

from random import getrandbits

from e2e.Libs.Minisketch import MinisketchLib, Sketch

from e2e.Meros.RPC import RPC

def HundredEightyOneTest(
  #rpc: RPC
) -> None:
  for _ in range(100):
    capacity: int = getrandbits(7) + 1
    sketch1: Sketch = Sketch(capacity)
    sketch2: Sketch = Sketch(capacity)
    difference: List[int] = []

    for _ in range(capacity + getrandbits(7)):
      sketch1.hashes.append(getrandbits(64))
      MinisketchLib.minisketch_add_uint64(sketch1.sketch, c_uint64(sketch1.hashes[-1]))

      if (getrandbits(2) == 0) and (len(difference) < capacity):
        difference.append(sketch1.hashes[-1])
      else:
        sketch2.hashes.append(sketch1.hashes[-1])
        MinisketchLib.minisketch_add_uint64(sketch2.sketch, c_uint64(sketch2.hashes[-1]))

    sketch2.merge(sketch1.serialize())
    if sorted(difference) != sketch2.decode():
      raise Exception("")

HundredEightyOneTest()
