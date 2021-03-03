import requests

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def BatchTest(
  rpc: RPC
) -> None:
  request: requests.Response = requests.post(
    "http://127.0.0.1:" + str(rpc.meros.rpc),
    json=[
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "merit_getHeight"
      },
      {
        "jsonrpc": "2.0",
        "id": 0,
        "method": "merit_getDifficulty"
      }
    ]
  )
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
    raise TestError("Meros didn't respond to a batch request properly.")

  """
  Also test handling of `[]`, which is valid JSON, yet shouldn't cause any JSON response.
  We also need to test authorization status inside batch requests.
  Finally, test quit. It should be non-compliant if followed by further requests, yet still respond with what it has.
  """
