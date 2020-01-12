#Types.
from typing import Any

#CTypes.
from ctypes import cdll, c_int, c_char, \
                   Array, c_char_p, c_void_p, create_string_buffer, byref

#OS standard lib.
import os

#Import the RandomX library.
#pylint: disable=invalid-name
RandomXLib: Any
if os.name == "nt":
    RandomXLib = cdll.LoadLibrary("PythonTests/Libs/mc_randomx/RandomX/build/randomx")
else:
    RandomXLib = cdll.LoadLibrary("PythonTests/Libs/mc_randomx/RandomX/build/librandomx.so")

#Define the function types.
RandomXLib.randomx_get_flags.randomx_get_flags = None
RandomXLib.randomx_get_flags.restype = c_int

RandomXLib.randomx_alloc_cache.argtypes = [c_int]
RandomXLib.randomx_alloc_cache.restype = c_void_p

RandomXLib.randomx_init_cache.argtypes = [c_void_p, c_char_p, c_int]
RandomXLib.randomx_init_cache.restype = None

RandomXLib.randomx_create_vm.argtypes = [c_int, c_void_p, c_void_p]
RandomXLib.randomx_create_vm.restype = c_void_p

RandomXLib.randomx_vm_set_cache.argtypes = [c_void_p, c_void_p]
RandomXLib.randomx_vm_set_cache.restype = None

RandomXLib.randomx_calculate_hash.argtypes = [c_void_p, c_char_p, c_int, c_void_p]
RandomXLib.randomx_calculate_hash.restype = None

flags: c_int = RandomXLib.randomx_get_flags()
cache: c_void_p = RandomXLib.randomx_alloc_cache(flags)
RandomXLib.randomx_init_cache(cache, None, 0)
vm: c_void_p = RandomXLib.randomx_create_vm(flags, cache, None)

def setRandomXKey(
    key: bytes
) -> None:
    RandomXLib.randomx_init_cache(cache, c_char_p(key), c_int(len(key)))
    RandomXLib.randomx_vm_set_cache(vm, cache)

def RandomX(
    data: bytes
) -> bytes:
    hashResult: Array[c_char] = create_string_buffer(32)
    RandomXLib.randomx_calculate_hash(vm, c_char_p(data), c_int(len(data)), byref(hashResult))

    result: bytes = bytes()
    for b in hashResult:
        result += b
    return result
