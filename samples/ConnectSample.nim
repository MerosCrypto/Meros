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

#Get the port.
echo "What is the RPC port of your node?"
port = parseInt(stdin.readLine())

echo "What IP do you want to connect to? "
payload = %* {
    "module": "network",
    "method": "connect",
    "args": [
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
echo (waitFor client.recvLine())
