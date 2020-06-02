#Types.
from typing import Dict, List, Any

#Meros class.
from PythonTests.Meros.Meros import Meros

#NodeError and TestError Exceptions.
from PythonTests.Tests.Errors import NodeError, TestError

#Remove standard function.
from os import remove

#Sleep standard function.
from time import sleep

#JSON standard lib.
import json

#Socket standard lib.
import socket

#RPC class.
class RPC:
  #Constructor.
  def __init__(
    self,
    meros: Meros
  ) -> None:
    self.meros: Meros = meros
    self.socket: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self.socket.connect(("127.0.0.1", meros.rpc))

  #Call an RPC method.
  def call(
    self,
    module: str,
    method: str,
    args: List[Any] = []
  ) -> Any:
    #Send the call.
    try:
      self.socket.send(
        bytes(
          json.dumps(
            {
              "jsonrpc": "2.0",
              "id": 0,
              "method": module + "_" + method,
              "params": args
            }
          ),
          "utf-8"
        )
      )
    except BrokenPipeError:
      raise NodeError()

    #Get the result.
    response: bytes = bytes()
    nextChar: bytes = bytes()
    counter: int = 0
    while True:
      try:
        nextChar = self.socket.recv(1)
      except Exception:
        raise NodeError()
      if not nextChar:
        raise NodeError()
      response += nextChar

      if response[-1] == response[0]:
        counter += 1
      elif (chr(response[-1]) == ']') and (chr(response[0]) == '['):
        counter -= 1
      elif (chr(response[-1]) == '}') and (chr(response[0]) == '{'):
        counter -= 1
      if counter == 0:
        break

    #Raise an exception on error.
    result: Dict[str, Any] = json.loads(response)
    if "error" in result:
      raise TestError(result["error"]["message"] + ".")
    return result["result"]

  #Quit Meros.
  def quit(
    self
  ) -> None:
    self.call("system", "quit")

  #Reset the Meros node.
  def reset(
    self
  ) -> None:
    #Quit Meros.
    self.quit()
    sleep(2)

    #Remove the existing DB files.
    remove("./data/PythonTests/devnet-" + self.meros.db)
    remove("./data/PythonTests/devnet-" + self.meros.db + "-lock")

    #Launch Meros.
    self.meros = Meros(self.meros.db, self.meros.tcp, self.meros.rpc)
    sleep(5)

    #Reconnect.
    self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self.socket.connect(("127.0.0.1", self.meros.rpc))
