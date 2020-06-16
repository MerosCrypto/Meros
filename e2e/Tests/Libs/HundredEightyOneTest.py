from typing import List
from ctypes import c_uint64

from random import getrandbits

from e2e.Libs.Pinsketch import encodeSketch, decodeSketch
from e2e.Libs.Minisketch import MinisketchLib, Sketch

from e2e.Tests.Errors import TestError

def HundredEightyOneTest() -> None:
  for _ in range(500):
    capacity: int = getrandbits(7) + 1
    sketches: List[Sketch] = [Sketch(capacity) for _ in range(2)]
    differences: List[int] = []

    for _ in range(capacity + getrandbits(7)):
      sketches[0].hashes.append(getrandbits(64))
      MinisketchLib.minisketch_add_uint64(sketches[0].sketch, c_uint64(sketches[0].hashes[-1]))

      if (getrandbits(2) == 0) and (len(differences) < capacity):
        differences.append(sketches[0].hashes[-1])
      else:
        sketches[1].hashes.append(sketches[0].hashes[-1])
        MinisketchLib.minisketch_add_uint64(sketches[1].sketch, c_uint64(sketches[1].hashes[-1]))
    differences = sorted(differences)

    miniSerialized: List[bytes] = [sketch.serialize() for sketch in sketches]
    pythonSerialized: List[bytes] = [encodeSketch(sketch.hashes, capacity) for sketch in sketches]
    for i in range(len(miniSerialized)):
      if miniSerialized[i] != pythonSerialized[i]:
        raise TestError("Pure Python Pinsketch encoded the sketch to a different serialization than Minisketch.")

    sketches[1].merge(miniSerialized[0])
    mergedArr: bytearray = bytearray()
    for i in range(len(pythonSerialized[0])):
      mergedArr.append(pythonSerialized[0][i] ^ pythonSerialized[1][i])
    merged: bytes = bytes(mergedArr)
    if merged != sketches[1].serialize():
      raise TestError("The merged Python sketch serialization is different than the Minisketch serialization of its merged Sketch.")

    if differences != sketches[1].decode():
      raise TestError("Minisketch didn't decode the differences.")
    if differences != decodeSketch(merged):
      raise TestError("Pure Python Pinsketch didn't decode the differences.")
