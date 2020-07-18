from typing import Dict, Any
from ctypes import cdll, c_int, c_char, \
           Array, c_char_p, c_void_p, create_string_buffer, byref

from threading import currentThread
import os

#Import the RandomX library.
#pylint: disable=invalid-name
RandomXLib: Any
if os.name == "nt":
  RandomXLib = cdll.LoadLibrary("e2e/Libs/mc_randomx/RandomX/build/randomx")
else:
  RandomXLib = cdll.LoadLibrary("e2e/Libs/mc_randomx/RandomX/build/librandomx.so")

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

caches: Dict[str, c_void_p] = {}
vms: Dict[str, c_void_p] = {}

def setRandomXKey(
  key: bytes
) -> None:
  name: str = currentThread().name
  if name not in caches:
    caches[name] = RandomXLib.randomx_alloc_cache(flags)
    vms[name] = RandomXLib.randomx_create_vm(flags, caches[name], None)

  RandomXLib.randomx_init_cache(caches[name], c_char_p(key), c_int(len(key)))
  RandomXLib.randomx_vm_set_cache(vms[name], caches[name])

def RandomX(
  data: bytes
) -> bytes:
  name: str = currentThread().name
  if name not in caches:
    raise Exception("RandomX hash called before this thread set a key.")

  hashResult: Array[c_char] = create_string_buffer(32)
  RandomXLib.randomx_calculate_hash(vms[name], c_char_p(data), c_int(len(data)), byref(hashResult))
  return bytes(hashResult)
