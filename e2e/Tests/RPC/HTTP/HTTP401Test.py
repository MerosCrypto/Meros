import requests

from e2e.Meros.Meros import Meros
from e2e.Tests.Errors import TestError

def HTTP401Test(
  meros: Meros
) -> None:
  for val in ["", "Bearer", "Bearer ", "Bearer X", "Bearer TEST", "NotBearer TEST_TOKEN"]:
    request: requests.Response = requests.post(
      "http://127.0.0.1:" + str(meros.rpc),
      json={
        "jsonrpc": "2.0",
        "id": 0,
        #Route which requires auth. Any would work.
        "method": "transactions_publishTransactionWithoutWork",
        #Stub params to ensure they're a non-issue.
        "params": {
          "type": "Data",
          "transaction": ""
        }
      },
      headers={
        "Authorization": val
      }
    )
    if request.status_code != 401:
      raise TestError("Meros didn't return 401 Unauthorized to an invalid authorization.")
