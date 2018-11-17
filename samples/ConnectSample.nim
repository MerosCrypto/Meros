#Networking standard libs.
import asyncdispatch, asyncnet

#JSON standard lib.
import json

var
    #Client socket.
    client: AsyncSocket = newAsyncSocket()
    #JSON payload.
    data: string
    #IP to connect to.
    ip: string

echo "What IP do you want to connect to? "
ip = stdin.readLine()

#Uglify the JSON.
toUgly(
    data,
    %* {
        "module": "network",
        "method": "connect",
        "args": [
            ip, 5132
        ]
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
