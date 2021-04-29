import os
import strutils
import tables
import json

import httpclient

#Argument types.
const ARGUMENTS: Table[string, seq[(string, char)]] = {
  "merit_getHeight":     @[],
  "merit_getDifficulty": @[],
  "merit_getBlock":      @[("block", 'i')],

  "merit_getPublicKey":     @[("nick", 'i')],
  "merit_getNickname":      @[("key", 'b')],
  "merit_getTotalMerit":    @[],
  "merit_getUnlockedMerit": @[],
  "merit_getMerit":         @[("nick", 'i')],

  "merit_getBlockTemplate": @[("miner", 'b')],
  "merit_publishBlock":     @[("id", 'i'), ("header", 'b')],

  "consensus_getSendDifficulty": @[],
  "consensus_getDataDifficulty": @[],
  "consensus_getStatus":         @[("hash", 'b')],

  "transactions_getTransaction": @[("hash", 'b')],
  "transactions_getUTXOs":       @[("address", 's')],
  "transactions_getBalance":     @[("address", 's')],

  "transactions_publishTransaction":            @[("type", 's'), ("transaction", 'b')],
  "transactions_publishTransactionWithoutWork": @[("type", 's'), ("transaction", 'b')],

  "network_connect":   @[("address", 's'), ("port", 'i')],
  "network_getPeers":  @[],
  "network_broadcast": @[("transaction", 'b')], #Skips over Block rebroadcasting as it should be extremely rarely needed.

  "personal_setWallet":  @[("mnemonic", 's'), ("password", 's')],
  "personal_setAccount": @[("key", 'b'), ("chainCode", 'b')],

  "personal_getMnemonic":        @[],
  "personal_getMeritHolderKey":  @[],
  "personal_getMeritHolderNick": @[],
  "personal_getAccount":         @[],
  "personal_getAddress":         @[],

  "personal_send": @[("outputs", 'j'), ("password", 's')],
  "personal_data": @[("data", 's'), ("password", 's')],

  "personal_getUTXOs":               @[],
  "personal_getTransactionTemplate": @[("outputs", 'j')], #Using this via the RPCSample would be incredibly pointless.
                                                          #That said, it is an RPC method, and could be used to demonstrate WatchWallet functionality.

  "system_quit": @[]
}.toTable()

proc readLine(): string =
  result = stdin.readLine()
  result.removePrefix(Whitespace)
  result.removeSuffix(Whitespace)

var
  port: int = 5133
  payload: JSONNode = %* {
    "jsonrpc": "2.0",
    "id": 0,
    "params": {}
  }
  p: int = 1

if paramCount() != 0:
  if (paramStr(p) == "-h") or (paramStr(p) == "--help"):
    echo """
Meros RPC Sample.
Parameters can be specified via command line arguments or the interactive
prompt.
./build/Sample <MODULE> <METHOD>
./build/Sample <MODULE> <METHOD <ARG_NAME> <ARG> <ARG_NAME> <ARG> ...
./build/Sample <PORT>
./build/Sample <PORT> <MODULE> <METHOD>
./build/Sample <PORT> <MODULE> <METHOD <ARG_NAME> <ARG> <ARG_NAME> <ARG> ..."""
    quit(1)

  try:
    port = parseInt(paramStr(p))
    inc(p)
  except ValueError:
    discard

if paramCount() >= p:
  payload["method"] = % paramStr(p)
  inc(p)

  if paramCount() < p:
    echo "Please supply the method with the module."
    quit(1)
  payload["method"] = % (payload["method"].getStr() & "_" & paramStr(p))
  inc(p)

  if not ARGUMENTS.hasKey(payload["method"].getStr()):
    echo "Invalid method."
    quit(1)

  while p <= paramCount():
    let
      fieldInfo: (string, char) = ARGUMENTS[payload["method"].getStr()][payload["params"].len]
      fieldName: string = fieldInfo[0]
    case fieldInfo[1]:
      of 's':
        payload["params"][fieldName] = % paramStr(p)

      of 'b':
        try:
          payload["params"][fieldName] = % parseHexStr(paramStr(p)).toHex()
        except ValueError:
          echo "Non-hex value passed at position ", p, "."
          quit(1)

      of 'i':
        try:
          payload["params"][fieldName] = % parseInt(paramStr(p))
        except ValueError:
          echo "Non-integer value passed at position ", p, "."
          quit(1)

      of 'j':
        try:
          payload["params"][fieldName] = parseJSON(paramStr(p))
        except ValueError:
          echo "Non-JSON value passed at position ", p, "."
          quit(1)

      else:
        doAssert(false, "Unknown argument type declared.")
    inc(p)

  if (payload["params"].len != 0) and (payload["params"].len != ARGUMENTS[payload["method"].getStr()].len):
    echo "Invalid amount of arguments."
    quit(1)

#If the method wasn't specified via the CLI, get it via the interactive prompt.
if not payload.hasKey("method"):
  echo "What module is your method in?"
  payload["method"] = % readLine()

  echo "What method are you trying to call?"
  payload["method"] = % (payload["method"].getStr() & "_" & readLine())

  if not ARGUMENTS.hasKey(payload["method"].getStr()):
    echo "Invalid method."
    quit(1)

#If the arguments weren't specificed via the CLI, get it via interactive prompt.
if payload["params"].len == 0:
  for arg in ARGUMENTS[payload["method"].getStr()]:
    let fieldName: string = arg[0]
    case arg[1]:
      of 's':
        echo "Please enter the next string argument for this method."
        payload["params"][fieldName] = % readLine()

      of 'b':
        echo "Please enter the next binary argument for this method as hex."
        while true:
          try:
            payload["params"][fieldName] = % parseHexStr(readLine()).toHex()
            break
          except ValueError:
            echo "Non-hex value passed. Please enter a hex value."

      of 'i':
        echo "Please enter the next integer argument for this method."
        while true:
          try:
            payload["params"][fieldName] = % parseInt(readLine())
            break
          except ValueError:
            echo "Non-integer value passed. Please enter an integer value."

      of 'j':
        echo "Please enter the next JSON argument for this method."
        while true:
          try:
            payload["params"][fieldName] = parseJSON(readLine())
            break
          except ValueError:
            echo "Non-JSON value passed. Please enter a JSON value."

      else:
        doAssert(false, "Unknown argument type declared.")

#Connect to the server, send the JSON, and get the response back.
var
  client: HttpClient = newHttpClient()
  headers: HttpHeaders = newHttpheaders()
headers["Authorization"] = "Bearer " & readFile("data/e2e/.token")
let res: JSONNode = parseJSON(
  client.request(
    "http://localhost:" & $port,
    "POST",
    $ payload,
    headers
  ).body
)
echo res
client.close()
