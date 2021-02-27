#Tests handling of Addresses by the RPC.
#Checks checksum mutability such as https://github.com/sipa/bech32/issues/51.
#Also checks:
# - Blatantly incorrect checksums.
# - Incorrect lengths.
# - Unsupported address types.

from typing import Union, List, Tuple

import os

from bech32 import CHARSET, convertbits, bech32_encode, bech32_decode

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import MessageException, TestError

def encodeAddress(
  data: bytes
) -> str:
  return bech32_encode("mr", convertbits(data, 8, 5))

def test(
  rpc: RPC,
  address: Union[bytes, str],
  invalid: bool,
  msg: str
) -> None:
  if isinstance(address, bytes):
    address = encodeAddress(address)

  try:
    rpc.call("transactions", "getBalance", {"address": address}, False)
    #If the call passed, and the address is invalid, raise.
    if invalid:
      raise MessageException(msg)
  except TestError as e:
    if int(e.message.split(" ")[0]) != -32602:
      raise Exception("Non-ParamError was raised by this RPC call, which shouldn't be able to raise anything else.")
    if not invalid:
      raise TestError(msg)
  except MessageException as e:
    raise TestError(e.message)

def AddressTest(
  rpc: RPC
) -> None:
  #Test a variety of valid addresses.
  for _ in range(50):
    test(rpc, bytes([0]) + os.urandom(32), False, "Meros rejected a valid address.")

  #Invalid checksum.
  invalidChecksum: str = encodeAddress(os.urandom(33))
  if invalidChecksum[-1] != 'q':
    invalidChecksum = invalidChecksum[:-1] + 'q'
  else:
    invalidChecksum = invalidChecksum[:-1] + 't'
  test(rpc, invalidChecksum, True, "Meros accepted an address with an invalid checksum.")

  #Invalid version byte.
  test(rpc, bytes([255]) + os.urandom(32), True, "Meros accepted an address with an invalid version byte.")

  #Invalid length.
  test(rpc, os.urandom(32), True, "Meros accepted an address with an invalid length.")
  test(rpc, os.urandom(34), True, "Meros accepted an address with an invalid length.")

  #Create a random address for us to mutate while preserving the checksum.
  randomKey: bytes = os.urandom(32)
  unchanged: str = encodeAddress(bytes([0]) + randomKey)
  #Sanity check against it.
  test(rpc, unchanged, False, "Meros rejected a valid address.")

  #Mutate it as described in https://github.com/sipa/bech32/issues/51#issuecomment-496797984.
  #Since we can insert any amount of 'q's, run this ten times.
  #It should be noted that this first insertion decodes to the same byte vector.
  #That said, the reference code is able to detect it as invalid due to its padding properties.
  #Because of that, it's noted here as an invalid case, to ensure compliance.
  for i in range(10):
    mutated: str = unchanged[:-1] + CHARSET[CHARSET.find(unchanged[-1]) ^ 1]
    #Just i would be 0 on the first run, which would be a NOP.
    #Therefore, a valid and unmodified address.
    mutated += "q" * (i + 1)
    mutated = mutated[:-1] + CHARSET[CHARSET.find(mutated[-1]) ^ 1]

    #Sanity check that our mutation worked.
    decoded: Union[Tuple[None, None], Tuple[str, List[int]]] = bech32_decode(mutated)
    if decoded is Tuple[None, None]:
      raise Exception("Mutation stopped the checksum from passing.")

    test(rpc, mutated, True, "Meros accepted an address which had been mutated yet still passed the checksum.")
