from typing import Union, List, Tuple

import os

from bech32 import CHARSET, convertbits, bech32_encode, bech32_decode

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

def encodeAddress(
  data: bytes
) -> str:
  return bech32_encode("mr", convertbits(data, 8, 5))

def AddressTest(
  rpc: RPC
) -> None:
  #Sanity test.
  try:
    rpc.call("personal", "send", [encodeAddress(bytes(33)), "1"])
    #Raise a TestError with a different code than expected to ensure the below check is run and fails.
    raise TestError("0 ")
  except TestError as e:
    if int(e.message.split(" ")[0]) != 1:
      raise TestError("Meros didn't use the NotEnoughMeros error when trying to send while having 0 Meros.")

  #Test a variety of valid addresses.
  for _ in range(50):
    try:
      rpc.call("personal", "send", [encodeAddress(bytes([0]) + os.urandom(32)), "1"])
      raise TestError("0 ")
    except TestError as e:
      if int(e.message.split(" ")[0]) != 1:
        raise TestError("Meros didn't use the NotEnoughMeros error when trying to send while having 0 Meros.")

  #Invalid checksum.
  invalidChecksum: str = encodeAddress(bytes(33))
  if invalidChecksum[-1] != 'q':
    invalidChecksum = invalidChecksum[:-1] + 'q'
  else:
    invalidChecksum = invalidChecksum[:-1] + 't'
  try:
    rpc.call("personal", "send", [invalidChecksum, "1"])
    raise TestError("0 ")
  except TestError as e:
    if int(e.message.split(" ")[0]) != -3:
      raise TestError("Meros accepted an address with an invalid checksum")

  #Invalid version byte. 255 was used as it's expected version bytes will become VarInts if ever needed.
  #That said, even 127 is high enough we're likely to never come close.
  try:
    rpc.call("personal", "send", [encodeAddress(bytes([255]) + bytes(32)), "1"])
    raise TestError("0 ")
  except TestError as e:
    if int(e.message.split(" ")[0]) != -3:
      raise TestError("Meros accepted an address with an invalid version byte.")

  #Invalid length.
  try:
    rpc.call("personal", "send", [encodeAddress(bytes(34)), "1"])
    raise TestError("0 ")
  except TestError as e:
    if int(e.message.split(" ")[0]) != -3:
      raise TestError("Meros accepted an address with an invalid length.")

  #Create a random address for us to mutate.
  randomKey: bytes = os.urandom(32)
  unchanged: str = encodeAddress(bytes([0]) + randomKey)
  #Sanity check against it.
  try:
    rpc.call("personal", "send", [unchanged, "1"])
    raise TestError("0 ")
  except TestError as e:
    if int(e.message.split(" ")[0]) != 1:
      raise TestError("Meros didn't use the NotEnoughMeros error when trying to send while having 0 Meros.")

  #Mutate it as described in https://github.com/sipa/bech32/issues/51#issuecomment-496797984.
  #Since we can insert any amount of 'q's, run this ten times.
  #It should be noted that this first insertion decodes to the same byte vector.
  #That said, the reference code is able to detect it as invalid due to its padding properties.
  #Because of that, it's noted here as an invalid case, to ensure compliance.
  for i in range(10):
    mutated: str = unchanged[:-1] + CHARSET[CHARSET.find(unchanged[-1]) ^ 1]
    #Just i would be 0 on the first run, which would be a NOP.
    mutated += "q" * (i + 1)
    mutated = mutated[:-1] + CHARSET[CHARSET.find(mutated[-1]) ^ 1]

    #Ensure it decodes properly with the library itself.
    #Sanity check that our mutation worked.
    decoded: Union[Tuple[None, None], Tuple[str, List[int]]] = bech32_decode(mutated)
    if decoded is Tuple[None, None]:
      raise TestError("Mutation stopped the checksum from passing.")

    try:
      rpc.call("personal", "send", [mutated, "1"])
      raise TestError("0 ")
    except TestError as e:
      if int(e.message.split(" ")[0]) != -3:
        raise TestError("Meros accepted an address which had been mutated yet still passed the checksum.")
