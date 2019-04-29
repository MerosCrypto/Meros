#Util lib.
import ../src/lib/Util

#BN/Hex lib.
import ../src/lib/Hex

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#Serialization libs.
import ../src/Network/Serialize/Lattice/SerializeSend
import ../src/Network/Serialize/Lattice/SerializeReceive

#Message object.
import ../src/Network/objects/MessageObj

#Networking/OS standard libs.
import asyncnet, asyncdispatch

#String utils standard lib.
import strutils

var
    answer: string                             #Answer to questions.

    address: string                            #Address to send/receive from.
    inputNonce: uint                           #Nonce of the Send to Receive from.
    amount: BN                                 #Amount we're sending.
    nonce: uint                                #Nonce of the Entry.

    wallet: Wallet                             #Wallet.

    send: Send                                 #Send object.
    recv: Receive                              #Receive object.

    handshake: string =                        #Handshake that says we're at Block 0.
        char(0) &
        char(0) &
        char(0) &
        char(MessageType.Handshake) & char(0)

    sendType: char = char(MessageType.Send)    #Send Message Type.
    recvType: char = char(MessageType.Receive) #Receive Message Type.
    serialized: string                         #Serialized string.

    client: AsyncSocket = newAsyncSocket()     #Socket.

#Get the Seed.
echo "What's the Wallet's Seed? If you don't have a Wallet, press enter to make one. "
answer = stdin.readLine()

#If they don't have a wallet, create a new one.
if answer == "":
    echo "Creating a new wallet..."
    wallet = newWallet()
    echo "Your Address is: " & wallet.address & "."
    echo "Your Seed is:    " & $wallet.seed & "."
    quit(0)

#Create a Wallet from their Seed.
wallet = newWallet(newEdSeed(answer))

#Get the Entry type.
echo "Would you like to Send or Receive a TX?"
answer = stdin.readLine()

#Handle a Send.
if answer.toLower() == "send":
    #Get the output/amount/nonce.
    echo "Who would you like to send to?"
    address = stdin.readLine()
    echo "How much would you like to send?"
    amount = newBN(stdin.readLine())
    echo "What nonce is this on your account?"
    nonce = parseUInt(stdin.readLine())

    #Create the Send.
    send = newSend(
        address,
        amount,
        nonce
    )
    #Sign the Send.
    wallet.sign(send)
    #Mine the Send.
    send.mine("".pad(128, "aa").toBNFromHex())

    #Create the serialized string.
    serialized = send.serialize()
    serialized = sendType & char(serialized.len) & serialized

#Handle a Receive.
elif answer.toLower() == "receive":
    #Get the intput address/input nonce/amount/nonce.
    echo "Who would you like to receive from?"
    address = stdin.readLine()
    echo "What nonce is the Send Entry on their account?"
    inputNonce = parseUInt(stdin.readLine())
    echo "What nonce is this on your account?"
    nonce = parseUInt(stdin.readLine())

    #Create the Receive.
    recv = newReceive(
        newIndex(
            address,
            inputNonce
        ),
        nonce
    )
    #Sign the Receive.
    wallet.sign(recv)
    echo "Signed the Receive."

    #Create the serialized string.
    serialized = recv.serialize()
    serialized = recvType & char(serialized.len) & serialized
else:
    echo "I don't recognize that option."
    quit(-1)

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(5132))
echo "Connected."

#Send the Handshake.
waitFor client.send(handshake)
echo "Handshaked."

#Send the serialized Entry.
waitFor client.send(serialized)
echo "Sent."
