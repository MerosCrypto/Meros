#Networking standard libs.
import asyncdispatch, asyncnet

#String utils standard lib.
import strutils

#JSON standard lib.
import json

var
    #Client socket.
    client: AsyncSocket = newAsyncSocket()
    #RPC port.
    port: int
    #Module.
    module: string
    #JSON.
    payload: JSONNode = %* {
        "jsonrpc": "2.0",
        "id": 0,
        "params": []
    }
    #Amount of arguments.
    argsLen: int
    #Response.
    res: string
    #Counter used to track if the response is complete.
    counter: int = 0

#Get the port.
echo "What is the RPC port of the node you want to connect to?"
port = parseInt(stdin.readLine())

#Get the module.
echo "What module is your method in?"
module = stdin.readLine()

#Get the method.
echo "What method are you trying to call?"
payload["method"] = % (module & "_" & stdin.readLine())

#Get the argument count.
echo "How many arguments are there?"
argsLen = parseInt(stdin.readLine())

#Get each argument.
for i in 0 ..< argsLen:
    echo "Is the next agument a (s)tring or an (i)nt?"
    var stringOrInt: string = stdin.readLine()

    echo "What is the argument?"
    if stringOrInt[0] == 's':
        payload["params"].add(% stdin.readLine())
    elif stringOrInt[0] == 'i':
        payload["params"].add(% parseInt(stdin.readLine()))

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
