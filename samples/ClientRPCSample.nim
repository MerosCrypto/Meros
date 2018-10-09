#Networking standard libs.
import asyncdispatch, asyncnet

#JSON standard lib.
import json

var
    #Client socket.
    client: AsyncSocket = newAsyncSocket()
    #JSON payload.
    data: string

#Uglify the JSON.
toUgly(
    data,
    %* {
        "module": "wallet",
        "method": "get",
        "args": []
    }
)

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(5133))
echo "Connected."

#Send the JSON.
waitFor client.send(data & "\r\n")
echo "Sent."

#Get the response back.
echo (waitFor client.recvLine())
