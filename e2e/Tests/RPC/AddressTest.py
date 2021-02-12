from typing import Union, List, Tuple

import os

from bech32 import CHARSET, convertbits, bech32_encode, bech32_decode

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

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
  try:
    if isinstance(address, bytes):
      address = encodeAddress(address)
    rpc.call("personal", "send", {"outputs": [{"address": address, "amount": "1"}]})
    #Raise a TestError with a different code than expected to ensure the below check is run and fails.
    raise TestError("0 ")
  except TestError as e:
    if int(e.message.split(" ")[0]) != (-3 if invalid else 1):
      raise TestError(msg)

def AddressTest(
  rpc: RPC
) -> None:
  #Sanity test.
  test(rpc, bytes(33), False, "Meros didn't use the NotEnoughMeros error when trying to send while having 0 Meros.")

  #Test a variety of valid addresses.
  for _ in range(50):
    test(rpc, bytes([0]) + os.urandom(32), False, "Meros didn't use the NotEnoughMeros error when trying to send while having 0 Meros.")

  #Invalid checksum.
  invalidChecksum: str = encodeAddress(bytes(33))
  if invalidChecksum[-1] != 'q':
    invalidChecksum = invalidChecksum[:-1] + 'q'
  else:
    invalidChecksum = invalidChecksum[:-1] + 't'
  test(rpc, invalidChecksum, True, "Meros accepted an address with an invalid checksum")

  #Invalid version byte. 255 was used as it's expected version bytes will become VarInts if ever needed.
  #That said, even 127 is high enough we're likely to never come close.
  test(rpc, bytes([255]) + bytes(32), True, "Meros accepted an address with an invalid version byte.")

  #Invalid length.
  test(rpc, bytes(32), True, "Meros accepted an address with an invalid length.")
  test(rpc, bytes(34), True, "Meros accepted an address with an invalid length.")

  #Create a random address for us to mutate.
  randomKey: bytes = os.urandom(32)
  unchanged: str = encodeAddress(bytes([0]) + randomKey)
  #Sanity check against it.
  test(rpc, unchanged, False, "Meros didn't use the NotEnoughMeros error when trying to send while having 0 Meros.")

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
      raise TestError("Mutation stopped the checksum from passing.")

    test(rpc, mutated, True, "Meros accepted an address which had been mutated yet still passed the checksum.")
