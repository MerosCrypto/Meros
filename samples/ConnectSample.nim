#Networking standard libs.
import asyncdispatch, asyncnet

#String utils standard lib.
import strutils

#JSON standard lib.
import json

var
    #Client socket.
    client: AsyncSocket = newAsyncSocket()
    #JSON.
    payload: JSONNode
    #RPC port.
    port: int
    #Response.
    res: string
    #Counter used to track if the response is complete.
    counter: int = 0

#Get the port.
echo "What is the RPC port of your node?"
port = parseInt(stdin.readLine())

echo "What IP do you want to connect to? "
payload = %* {
    "jsonrpc": "2.0",
    "id": 0,
    "method": "network_connect",
    "params": [
        stdin.readLine()
    ]
}

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(port))
echo "Connected."

#Send the JSON.
waitFor client.send($payload & "\r\n")
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
