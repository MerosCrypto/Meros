from typing import Dict, Any
import json

import ed25519
import requests

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def reqIter() -> str:
  yield b"["
  yield json.dumps({
    "jsonrpc": "2.0",
    "id": 1,
    "method": "merit_getHeight"
  }).encode() + b","
  yield json.dumps({
    "jsonrpc": "2.0",
    "id": 0,
    "method": "merit_getDifficulty"
  }).encode()
  yield b"]"

def ChunkedEncodingTest(
  rpc: RPC
) -> None:
  request: requests.Response = requests.post("http://127.0.0.1:" + str(rpc.meros.rpc), data=reqIter())
  if request.status_code != 200:
    raise TestError("HTTP status isn't 200: " + str(request.status_code))
  if request.json() != [
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": 1
    },
    {
      "jsonrpc": "2.0",
      "id": 0,
      "result": Blockchain().difficulty()
    }
  ]:
    raise TestError("Meros didn't respond to a batch request (sent as chunks) properly.")
