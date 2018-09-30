#Util lib.
import ../src/lib/Util

#Numerical libs.
import BN
import ../src/lib/Base

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#Serialization libs.
import ../src/Network/Serialize/SerializeSend
import ../src/Network/Serialize/SerializeReceive

#Networking/OS standard libs.
import asyncnet, asyncdispatch

#String utils standard lib.
import strutils

var
    answer: string                         #Answer to questions.

    address: string                        #Address to send/receive from.
    inputNonce: BN                         #Nonce of the Send to Receive from.
    amount: BN                             #Amount we're sending.
    nonce: BN                              #Nonce of the Node.

    wallet: Wallet                         #Wallet.

    send: Send                             #Send object.
    recv: Receive                          #Receive object.

    sendHeader: string =                   #Send header.
        $(char(0)) &
        $(char(0)) &
        $(char(0))
    recvHeader: string =                   #Receive header.
        $(char(0)) &
        $(char(0)) &
        $(char(1))
    serialized: string                     #Serialized string.

    client: AsyncSocket = newAsyncSocket() #Socket.

#Get the PrivateKey.
echo "What's the Wallet's Private Key? If you don't have a Wallet, press enter to make one. "
answer = stdin.readLine()

#If they don't have a wallet, create a new one.
if answer == "":
    echo "Creating a new wallet..."
    wallet = newWallet()
    echo "Your Address is:     " & wallet.address & "."
    echo "Your Private Key is: " & $wallet.privateKey & "."
    quit(0)

#Create a Wallet from their Private Key.
wallet = newWallet(answer)

#Get the TX type.
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
    nonce = newBN(stdin.readLine())

    #Create the Send.
    send = newSend(
        address,
        amount,
        nonce
    )
    #Mine the Send.
    send.mine("".pad(128, "aa").toBN(16))
    #Sign the Send.
    echo "Signing the Send retuned... " & $wallet.sign(send)

    #Create the serialized string.
    serialized = send.serialize()
    serialized = sendHeader & char(serialized.len) & serialized

#Handle a Receive.
elif answer.toLower() == "receive":
    #Get the intput address/input nonce/amount/nonce.
    echo "Who would you like to receive from?"
    address = stdin.readLine()
    echo "What nonce is the send block on their account?"
    inputNonce = newBN(stdin.readLine())
    echo "What nonce is this on your account?"
    nonce = newBN(stdin.readLine())

    #Create the Receive.
    recv = newReceive(
        address,
        inputNonce,
        nonce
    )
    #Sign the Receive.
    wallet.sign(recv)
    echo "Signed the Receive."

    #Create the serialized string.
    serialized = recv.serialize()
    serialized = recvHeader & char(serialized.len) & serialized
else:
    echo "I don't recognize that option."
    quit(-1)

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(5132))
echo "Connected."
#Send the serialized node.
waitFor client.send(serialized)
echo "Sent."
