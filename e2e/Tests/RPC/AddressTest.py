#Tests handling of Addresses by the RPC.
#Checks checksum mutability such as https://github.com/sipa/bech32/issues/51.
#Also checks:
# - Blatantly incorrect checksums.
# - Incorrect lengths.
# - Unsupported address types.

from typing import Union

import os

import bech32ref.segwit_addr as segwit_addr

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import MessageException, TestError

def encodeAddress(
  addyType: int,
  data: bytes
) -> str:
  return segwit_addr.encode("mr", addyType, data)

def test(
  rpc: RPC,
  addyType: int,
  address: Union[bytes, str],
  invalid: bool,
  msg: str
) -> None:
  if isinstance(address, bytes):
    address = encodeAddress(addyType, address)

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
    test(rpc, 1, os.urandom(32), False, "Meros rejected a valid address.")

  #Invalid checksum.
  invalidChecksum: str = encodeAddress(1, os.urandom(32))
  if invalidChecksum[-1] != 'q':
    invalidChecksum = invalidChecksum[:-1] + 'q'
  else:
    invalidChecksum = invalidChecksum[:-1] + 't'
  test(rpc, 1, invalidChecksum, True, "Meros accepted an address with an invalid checksum.")

  #Invalid version byte.
  test(rpc, 0, os.urandom(32), True, "Meros accepted an address with an invalid version byte.")
  test(rpc, 2, os.urandom(32), True, "Meros accepted an address with an invalid version byte.")

  #Invalid length.
  test(rpc, 1, os.urandom(31), True, "Meros accepted an address with an invalid length.")
  test(rpc, 1, os.urandom(33), True, "Meros accepted an address with an invalid length.")
