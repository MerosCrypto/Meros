from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

def IntegerBoundTest(
  rpc: RPC
) -> None:
  #uint16.
  try:
    rpc.call("merit", "getPublicKey", {"holder": -1})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted a negative integer for an unsigned integer.")

  try:
    rpc.call("merit", "getPublicKey", {"holder": 65536})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted a too large unsigned integer.")

  #uint.
  try:
    rpc.call("merit", "getBlock", {"block": -1})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted a negative integer for an unsigned integer.")

  try:
    rpc.call("merit", "getBlock", {"block": (2 ** 63)})
    raise TestError()
  except Exception as e:
    if str(e) != "-32700 Parse error.":
      raise TestError("Meros parsed an integer outside of the int64 bounds.")

  try:
    rpc.call("merit", "getBlock", {"block": (2 ** 64)})
    raise TestError()
  except Exception as e:
    if str(e) != "-32700 Parse error.":
      raise TestError("Meros parsed an integer outside of the uint64 bounds.")
