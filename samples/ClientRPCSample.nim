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
        "method": "set",
        "args": [
            "7A3E64ADDB86DA2F3D1BEF18F6D2C80BA5C5EF9673DE8A0F5787DF8E6DD237427DE33230FC0FC66D1F5EF63BA5BD7536817873257928F9ADC08B532A5CCE5575"
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
