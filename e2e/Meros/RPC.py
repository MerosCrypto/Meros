from typing import Dict, Any
from os import remove
from time import sleep

import requests

from e2e.Meros.Meros import Meros

from e2e.Tests.Errors import NodeError, TestError

class RPC:
  def __init__(
    self,
    meros: Meros
  ) -> None:
    self.meros: Meros = meros

  def call(
    self,
    module: str,
    method: str,
    args: Dict[str, Any] = {}
  ) -> Any:
    try:
      request: requests.Response = requests.post("http://127.0.0.1:" + str(self.meros.rpc), json={
        "jsonrpc": "2.0",
        "id": 0,
        "method": module + "_" + method,
        "params": args
      })
    except Exception as e:
      raise NodeError(str(e))

    if request.status_code != 200:
      raise TestError("HTTP status isn't 200: " + str(request.status_code))
    result: Dict[str, Any] = request.json()

    if "error" in result:
      raise TestError(str(result["error"]["code"]) + " " + result["error"]["message"] + ".")
    return result["result"]

  def quit(
    self
  ) -> None:
    self.meros.quit()

  #Reset the Meros node, deleting its Database and rebooting it.
  def reset(
    self
  ) -> None:
    self.quit()
    sleep(3)

    try:
      remove("./data/e2e/devnet-" + self.meros.db)
    except FileNotFoundError:
      pass
    try:
      remove("./data/e2e/devnet-" + self.meros.db + "-lock")
    except FileNotFoundError:
      pass

    self.meros = Meros(self.meros.db, self.meros.tcp, self.meros.rpc)
    sleep(5)
