#Tests handling of Addresses by the RPC.
#Checks checksum mutability such as https://github.com/sipa/bech32/issues/51.
#Also checks:
# - Blatantly incorrect checksums.
# - Incorrect lengths.
# - Unsupported address types.

from typing import Union

import os

from bech32ref.segwit_addr import Encoding, convertbits, bech32_encode

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import MessageException, TestError

def encodeAddress(
  data: bytes
) -> str:
  return bech32_encode("mr", convertbits(data, 8, 5), Encoding.BECH32M)

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
