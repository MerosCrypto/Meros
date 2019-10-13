#Types.
from typing import List, Any
from ctypes import Array, c_uint64, c_uint32, c_size_t, c_char, c_char_p

#OS standard lib.
import os

#CTypes functions.
#pylint: disable=ungrouped-imports
from ctypes import cdll, create_string_buffer, byref

#SketchError Exception. Used when a sketch has more differences than its capacity.
class SketchError(Exception):
    pass

#Import the Minisketch library.
#pylint: disable=invalid-name
MinisketchLib: Any
if os.name == "nt":
    MinisketchLib = cdll.LoadLibrary("PythonTests/Stubs/minisketch")
else:
    MinisketchLib = cdll.LoadLibrary("PythonTests/Stubs/libminisketch.so")

#Sketch class.
class Sketch():
    #Constructor.
    def __init__(
        self,
        capacity: int
    ) -> None:
        self.capacity: int = capacity
        self.sketch: Any = MinisketchLib.minisketch_create(c_uint32(12), c_uint32(0), c_size_t(self.capacity))

    #Add an element.
    def add(
        self,
        value: int
    ) -> None:
        MinisketchLib.minisketch_add_uint64(self.sketch, c_uint64(value))

    #Serialize a sketch.
    def serialize(
        self
    ) -> bytes:
        serialization: Array[c_char] = create_string_buffer(MinisketchLib.minisketch_serialized_size(self.sketch))
        MinisketchLib.minisketch_serialize(self.sketch, byref(serialization))

        result: bytes = bytes()
        for b in serialization:
            result += b
        return result

    #Merge two sketches.
    def merge(
        self,
        other: bytes
    ):
        serialized: bytes = self.serialize()
        merged: bytearray = bytearray()
        for b in range(len(serialized)):
            merged.append(serialized[b] ^ other[b])
        MinisketchLib.minisketch_deserialize(self.sketch, c_char_p(bytes(merged)))

    #Decode a sketch's differences.
    def decode(
        self
    ) -> List[int]:
        decoded: Array[c_uint64] = (c_uint64 * self.capacity)()
        differences: int = MinisketchLib.minisketch_decode(self.sketch, c_size_t(self.capacity), byref(decoded))

        if differences == -1:
            raise SketchError("The amount of differences is greater than the capacity.")

        result: List[int] = []
        for diff in range(differences):
            result.append(decoded[diff])
        return sorted(result)
