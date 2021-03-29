from typing import Dict, List, Union, Any

import requests

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def request(
  rpc: RPC,
  req: Union[List[Any], Dict[str, Any]],
  headers: Dict[str, str] = {}
) -> Union[List[Any], Dict[str, Any]]:
  res: requests.Response = requests.post(
    "http://127.0.0.1:" + str(rpc.meros.rpc),
    headers=headers,
    json=req
  )
  if res.status_code != 200:
    raise TestError("HTTP status isn't 200: " + str(res.status_code))
  return res.json()

def BatchTest(
  rpc: RPC
) -> None:
  #Most basic case; two valid requests.
  if request(
    rpc,
    [
      {"jsonrpc": "2.0", "id": 1, "method": "merit_getHeight"},
      {"jsonrpc": "2.0", "id": 0, "method": "merit_getDifficulty"}
    ]
  ) != [
    {"jsonrpc": "2.0", "id": 1, "result": 1},
    {"jsonrpc": "2.0", "id": 0, "result": Blockchain().difficulty()}
  ]:
    raise TestError("Meros didn't respond to a batch request properly.")

  #Test handling of empty batches.
  if request(rpc, []) != {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": None}:
    raise TestError("Empty batch wasn't handled correctly.")

  #Batches with invalid individual requests.
  if request(rpc, [1, 2, 3]) != [
    {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": None},
    {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": None},
    {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": None}
  ]:
    raise TestError("Batch with invalid individual entries wasn't handled correctly.")

  if request(
    rpc, [
      1,
      {"jsonrpc": "2.0", "id": 1, "method": "merit_getHeight"},
      2
    ]) != [
    {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": None},
    {"jsonrpc": "2.0", "id": 1, "result": 1},
    {"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": None}
  ]:
    raise TestError("Batch with some invalid individual entries wasn't handled correctly.")

  #Test authorization.
  #If the token is passed, calling multiple methods requiring authorization should work.
  #If not passing a token, calling multiple methods not requiring authorization should work. This is tested implicitly by the first test case here.
  #If not passing a token, or passing an invalid token, calling any method requiring auth should cause the entire request to 401.
  multipleAuthed: Union[List[Any], Dict[str, Any]] = request(
    rpc,
    [
      {"jsonrpc": "2.0", "id": 0, "method": "personal_setWallet"},
      {"jsonrpc": "2.0", "id": 1, "method": "personal_getMnemonic"},
    ],
    {"Authorization": "Bearer TEST_TOKEN"}
  )
  if isinstance(multipleAuthed, List):
    if multipleAuthed != [
      {"jsonrpc": "2.0", "id": 0, "result": True},
      #The Mnemonic will be random, hence this.
      {"jsonrpc": "2.0", "id": 1, "result": multipleAuthed[1]["result"]}
    ]:
      raise TestError("Batch request didn't work when it had multiple methods requiring authentication.")
  else:
    raise TestError("Response to a batch request wasn't a list.")

  #Not passing a token.
  try:
    request(
      rpc,
      [
        {"jsonrpc": "2.0", "id": 0, "method": "merit_getHeight"},
        {"jsonrpc": "2.0", "id": 1, "method": "personal_setWallet"},
        {"jsonrpc": "2.0", "id": 2, "method": "merit_getHeight"}
      ]
    )
    raise Exception()
  except Exception as e:
    if str(e) != "HTTP status isn't 200: 401":
      raise TestError("Meros didn't respond to a batch request without authorization yet needing it as expected.")

  #Invalid token.
  try:
    request(
      rpc,
      [
        {"jsonrpc": "2.0", "id": 0, "method": "merit_getHeight"},
        {"jsonrpc": "2.0", "id": 1, "method": "personal_setWallet"},
        {"jsonrpc": "2.0", "id": 2, "method": "merit_getHeight"}
      ],
      {"Authorization": "Bearer INVALID_TOKEN"}
    )
    raise Exception()
  except Exception as e:
    if str(e) != "HTTP status isn't 200: 401":
      raise TestError("Meros didn't respond to a batch request without authorization yet needing it as expected.")

  #Test batch requests containing quit.
  #Meros should return responses for all requests it handled before quit, yet still quit without further handling.
  if request(
    rpc,
    [
      {"jsonrpc": "2.0", "id": 0, "method": "merit_getHeight"},
      {"jsonrpc": "2.0", "id": 1, "method": "system_quit"},
      {"jsonrpc": "2.0", "id": 2, "method": "merit_getDifficulty"},
    ],
    {"Authorization": "Bearer TEST_TOKEN"}
  ) != [
    {"jsonrpc": "2.0", "id": 0, "result": 1},
    {"jsonrpc": "2.0", "id": 1, "result": True}
  ]:
    raise TestError("Meros didn't respond to a batch request containing quit as expected.")

  #Mark Meros as having called quit so teardown works.
  rpc.meros.calledQuit = True
