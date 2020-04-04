#Chronos external lib.
import chronos

#OS standard lib.
import os

#String utils standard lib.
import strutils

#Tables standard lib.
import tables

#JSON standard lib.
import json

#Argument types.
const ARGUMENTS: Table[string, seq[char]] = {
    "merit_getHeight":             @[],
    "merit_getDifficulty":         @[],
    "merit_getBlock":              @['i'],

    "merit_getTotalMerit":         @[],
    "merit_getUnlockedMerit":      @[],
    "merit_getMerit":              @['i'],

    "merit_getBlockTemplate":      @['b'],
    "merit_publishBlock":          @['i', 'b'],

    "consensus_getSendDifficulty": @[],
    "consensus_getDataDifficulty": @[],
    "consensus_getStatus":         @['b'],

    "transactions_getTransaction": @['b'],
    "transactions_getBalance":     @['s'],

    "network_connect":             @['s', 'i'],
    "network_getPeers":            @[],

    "personal_getMiner":           @[],
    "personal_setMnemonic":        @['b', 'b'],
    "personal_getAddress":         @[],

    "personal_send":               @['s', 's'],
    "personal_data":               @['s']
}.toTable()

var
    #Client socket.
    client: AsyncSocket = newAsyncSocket()
    #RPC port.
    port: int = 5133
    #JSON.
    payload: JSONNode = %* {
        "jsonrpc": "2.0",
        "id": 0,
        "params": []
    }
    #Current argument.
    p: int = 1
    #Response.
    res: string
    #Counter used to track if the response is complete.
    counter: int = 0

if paramCount() != 0:
    if (paramStr(p) == "-h") or (paramStr(p) == "--help"):
        echo """
Meros RPC Sample.
Parameters can be specified via command line arguments or the interactive
prompt.

./build/Sample <MODULE> <METHOD>
./build/Sample <MODULE> <METHOD <ARG> <ARG> ...
./build/Sample <PORT>
./build/Sample <PORT> <MODULE> <METHOD>
./build/Sample <PORT> <MODULE> <METHOD <ARG> <ARG> ..."""
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
        case ARGUMENTS[payload["method"].getStr()][payload["params"].len]:
            of 's':
                payload["params"].add(% paramStr(p))

            of 'b':
                try:
                    payload["params"].add(% parseHexStr(paramStr(p)).toHex())
                except ValueError:
                    echo "Non-hex value passed at position ", p, "."
                    quit(1)

            of 'i':
                try:
                    payload["params"].add(% parseInt(paramStr(p)))
                except ValueError:
                    echo "Non-integer value passed at position ", p, "."
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
    payload["method"] = % stdin.readLine()

    echo "What method are you trying to call?"
    payload["method"] = % (payload["method"].getStr() & "_" & stdin.readLine())

    if not ARGUMENTS.hasKey(payload["method"].getStr()):
        echo "Invalid method."
        quit(1)

#If the arguments weren't specificed via the CLI, get it via interactive prompt.
if payload["params"].len == 0:
    for arg in ARGUMENTS[payload["method"].getStr()]:
        case arg:
            of 's':
                echo "Please enter the next string argument for this method."
                payload["params"].add(% stdin.readLine())

            of 'b':
                echo "Please enter the next binary argument for this method as hex."
                while true:
                    try:
                        payload["params"].add(% parseHexStr(stdin.readLine()).toHex())
                        break
                    except ValueError:
                        echo "Non-hex value passed. Please enter an integer value."

            of 'i':
                echo "Please enter the next integer argument for this method."
                while true:
                    try:
                        payload["params"].add(% parseInt(stdin.readLine()))
                        break
                    except ValueError:
                        echo "Non-integer value passed. Please enter an integer value."

            else:
                doAssert(false, "Unknown argument type declared.")

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(port))
echo "Connected."

#Send the JSON.
waitFor client.send($payload)
echo "Sent."

#Get the response back.
while true:
    res &= waitFor client.recv(1)
    if res[^1] == res[0]:
        inc(counter)
    elif (res[^1] == ']') and (res[0] == '['):
        dec(counter)
    elif (res[^1] == '}') and (res[0] == '{'):
        dec(counter)
    if counter == 0:
        break

#Print it.
echo res
