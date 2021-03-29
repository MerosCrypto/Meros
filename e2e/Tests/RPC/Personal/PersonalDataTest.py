from time import sleep

from typing import Dict, Any

from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError
from e2e.Tests.RPC.Personal.Lib import decodeAddress

def checkData(
  rpc: RPC,
  dataHash: str,
  expected: bytes
) -> str:
  data: Dict[str, Any] = rpc.call("transactions", "getTransaction", {"hash": dataHash})

  if len(data["inputs"]) != 1:
    raise TestError("Data had multiple inputs.")
  res: str = data["inputs"][0]["hash"]
  del data["inputs"]
  del data["signature"]
  del data["proof"]

  if data != {
    "descendant": "Data",
    "outputs": [],
    "hash": dataHash,
    "data": expected.hex().upper()
  }:
    raise TestError("Data wasn't as expected.")

  return res

def PersonalDataTest(
  rpc: RPC
) -> None:
  #Create a Data.
  firstData: str = rpc.call("personal", "data", {"data": "a"})
  initial: str = checkData(rpc, firstData, b"a")

  #Meros should've also created an initial Data.
  if checkData(rpc, initial, decodeAddress(rpc.call("personal", "getAddress"))) != bytes(32).hex():
    raise TestError("Initial Data didn't have a 0-hash input.")

  #Create a Data using hex data. Also tests upper case hex.
  if checkData(rpc, rpc.call("personal", "data", {"data": "AABBCC", "hex": True}), b"\xAA\xBB\xCC") != firstData:
    raise TestError("Newly created Data wasn't a descendant of the existing Data.")

  #Should support using 256 bytes of Data. Also tests lower case hex.
  checkData(rpc, rpc.call("personal", "data", {"data": bytes([0xaa] * 256).hex(), "hex": True}), bytes([0xaa] * 256))

  #Should properly error when we input no data. All Datas must have at least 1 byte of Data.
  try:
    rpc.call("personal", "data", {"data": ""})
    raise Exception()
  except Exception as e:
    if str(e) != "-3 Data is too small or too large.":
      raise TestError("Meros didn't handle Data that was too small.")

  #Should properly error when we supply more than 256 bytes of data.
  try:
    rpc.call("personal", "data", {"data": "a" * 257})
    raise Exception()
  except Exception as e:
    if str(e) != "-3 Data is too small or too large.":
      raise TestError("Meros didn't handle Data that was too large.")

  #Should properly error when we supply non-hex data with the hex flag.
  try:
    rpc.call("personal", "data", {"data": "zz", "hex": True})
    raise Exception()
  except Exception as e:
    if str(e) != "-3 Invalid hex char `z` (ord 122).":
      raise TestError("Meros didn't properly handle invalid hex.")

  #Should properly error when we supply non-even hex data.
  try:
    rpc.call("personal", "data", {"data": "a", "hex": True})
    raise Exception()
  except Exception as e:
    if str(e) != "-3 Incorrect hex string len.":
      raise TestError("Meros didn't properly handle non-even hex.")

  #Test Datas when the Wallet has a password.
  rpc.call("personal", "setWallet", {"password": "password"})

  #Shouldn't work due to the lack of a password.
  try:
    rpc.call("personal", "data", {"data": "abc"})
    raise Exception()
  except Exception as e:
    if str(e) != "-3 Invalid password.":
      raise TestError("Meros didn't properly handle creating a Data without a password.")

  #Should work due to the existence of a password.
  lastData: str = rpc.call("personal", "data", {"data": "abc", "password": "password"})
  checkData(rpc, lastData, b"abc")

  #Reboot the node and verify we can create a new Data without issue.
  rpc.quit()
  sleep(3)
  rpc.meros = Meros(rpc.meros.db, rpc.meros.tcp, rpc.meros.rpc)
  if checkData(rpc, rpc.call("personal", "data", {"data": "def", "password": "password"}), b"def") != lastData:
    raise TestError("Couldn't create a new Data after rebooting.")
