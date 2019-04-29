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
    #JSON.
    payload: JSONNode = %* {
        "args": []
    }
    #Amount of arguments.
    argsLen: int

#Get the port.
echo "What is the RPC port of the node you want to connect to?"
port = parseInt(stdin.readLine())

#Get the module.
echo "What module is your method in?"
payload["module"] = % stdin.readLine()

#Get the method.
echo "What method are you trying to call?"
payload["method"] = % stdin.readLine()

#Get the argument count.
echo "How many arguments are there?"
argsLen = parseInt(stdin.readLine())

#Get each argument.
for i in 0 ..< argsLen:
    echo "Is the next agument a (s)tring or an (i)nt?"
    var stringOrInt: string = stdin.readLine()

    echo "What is the argument?"
    if stringOrInt[0] == 's':
        payload["args"].add(% stdin.readLine())
    elif stringOrInt[0] == 'i':
        payload["args"].add(% parseInt(stdin.readLine()))

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(port))
echo "Connected."

#Send the JSON.
waitFor client.send($payload & "\r\n")
echo "Sent."

#Get the response back.
echo (waitFor client.recvLine())
