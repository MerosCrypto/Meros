#Types.
from typing import List, Any

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#CTypes.
from ctypes import cdll, c_uint64, c_uint32, c_size_t, c_char, \
                   Array, c_char_p, c_void_p, create_string_buffer, byref

#OS standard lib.
import os

#Blake2b standard function.
from hashlib import blake2b

#SketchError Exception. Used when a sketch has more differences than its capacity.
class SketchError(
    Exception
):
    pass

#Import the Minisketch library.
#pylint: disable=invalid-name
MinisketchLib: Any
if os.name == "nt":
    MinisketchLib = cdll.LoadLibrary("PythonTests/Libs/minisketch")
else:
    MinisketchLib = cdll.LoadLibrary("PythonTests/Libs/libminisketch.so")

#Define the function types.
MinisketchLib.minisketch_create.argtypes = [c_uint32, c_uint32, c_size_t]
MinisketchLib.minisketch_create.restype = c_void_p

MinisketchLib.minisketch_add_uint64.argtypes = [c_void_p, c_uint64]
MinisketchLib.minisketch_add_uint64.restype = None

MinisketchLib.minisketch_serialize.argtypes = [c_void_p, c_void_p]
MinisketchLib.minisketch_serialize.restype = None

MinisketchLib.minisketch_deserialize.argtypes = [c_void_p, c_char_p]
MinisketchLib.minisketch_deserialize.restype = None

MinisketchLib.minisketch_decode.argtypes = [c_void_p, c_size_t, c_void_p]
MinisketchLib.minisketch_decode.restype = c_size_t

#Sketch class.
class Sketch:
    #Constructor.
    def __init__(
        self,
        capacity: int
    ) -> None:
        self.capacity: int = capacity
        if self.capacity != 0:
            self.sketch: Any = MinisketchLib.minisketch_create(c_uint32(64), c_uint32(0), c_size_t(self.capacity))

    @staticmethod
    def hash(
        sketchSalt: bytes,
        packet: VerificationPacket
    ) -> int:
        return int.from_bytes(
            blake2b(sketchSalt + packet.serialize(), digest_size=8).digest(),
            byteorder="big"
        )

    #Add a Packet.
    def add(
        self,
        sketchSalt: bytes,
        packet: VerificationPacket
    ) -> None:
        MinisketchLib.minisketch_add_uint64(self.sketch, c_uint64(Sketch.hash(sketchSalt, packet)))

    #Serialize a sketch.
    def serialize(
        self
    ) -> bytes:
        if self.capacity == 0:
            return bytes()

        serialization: Array[c_char] = create_string_buffer(self.capacity * 8)
        MinisketchLib.minisketch_serialize(self.sketch, byref(serialization))

        result: bytes = bytes()
        for b in serialization:
            result += b
        return result

    #Merge two sketches.
    def merge(
        self,
        other: bytes
    ) -> None:
        serialized: bytes = self.serialize()
        merged: bytearray = bytearray()
        for b in range(len(serialized)):
            merged.append(serialized[b] ^ other[b])
        MinisketchLib.minisketch_deserialize(self.sketch, c_char_p(bytes(merged)))

    #Decode a sketch's differences.
    def decode(
        self
    ) -> List[int]:
        if self.capacity == 0:
            return []

        decoded: Array[c_uint64] = (c_uint64 * self.capacity)()
        differences: int = MinisketchLib.minisketch_decode(self.sketch, c_size_t(self.capacity), byref(decoded))

        if differences == -1:
            raise SketchError("The amount of differences is greater than the capacity.")

        result: List[int] = []
        for diff in range(differences):
            result.append(decoded[diff])
        return sorted(result)
