from typing import Any
import json

import requests

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def request(
  rpc: RPC,
  req: Any
):
  res: requests.Response = requests.post(
    "http://127.0.0.1:" + str(rpc.meros.rpc),
    data=json.dumps(req)
  )
  if res.status_code != 200:
    raise TestError("HTTP status isn't 200: " + str(res.status_code))
  if res.json() != {"jsonrpc": "2.0", "id": None, "error": {"code": -32600, "message": "Invalid Request"}}:
    raise TestError("Invalid request wasn't considered invalid.")

def InvalidRequestTest(
  rpc: RPC
) -> None:
  #Try a bool as a request object.
  request(rpc, True)
  #Try a string.
  request(rpc, "")
  #Try an int.
  request(rpc, 5)
  #Try a float.
  request(rpc, 1.0)
  #Try null.
  request(rpc, None)

  #Empty object.
  request(rpc, {})
  #Valid request except the ID is an object.
  request(rpc, {"jsonrpc": "2.0", "id": {}, "method": "merit_getHeight"})
