#Util lib.
import lib/Util

#Numerical libs.
import lib/BN
import lib/Base

#Wallet lib.
import Wallet/Wallet

#Lattice lib.
import Database/Lattice/Lattice

#Serialization libs.
import Network/Serialize/SerializeSend
import Network/Serialize/SerializeReceive

#Networking/OS standard lib.
import net, os

#String utils standard lib.
import strutils

var
    #Answer to questions.
    answer: string

    #TX data.
    address: string
    inputNonce: BN
    amount: BN
    nonce: BN

    #Wallet.
    wallet: Wallet

    #TX objects.
    send: Send
    recv: Receive

    #Header/serialized data string.
    header: string
    serialized: string

    #Socket.
    client: Socket = newSocket()

#Get the PrivateKey.
echo "What's the Wallet's Private Key? If you don't have a Wallet, press enter to make one. "
answer = stdin.readLine()

#If they don't have a wallet, create a new one.
if answer == "":
    echo "Creating a new wallet..."
    wallet = newWallet()
    echo "Your Address is:     " & wallet.getAddress() & "."
    echo "Your Private Key is: " & $wallet.getPrivateKey() & "."
    quit(0)

#Create a Wallet from their Private Key.
wallet = newWallet(answer)

#DGet the TX type.
echo "Would you like to Send or Receive a TX?"
answer = stdin.readLine()

if answer.toLower() == "send":
    echo "Who would you like to send to?"
    address = stdin.readLine()
    echo "How much would you like to send?"
    amount = newBN(stdin.readLine())
    echo "What nonce is this on your account?"
    nonce = newBN(stdin.readLine())

    send = newSend(
        address,
        amount,
        nonce
    )
    send.mine("".pad(64, "88").toBN(16))
    echo "Signing the Send retuned... " & $wallet.sign(send)

    header =
        $((char) 0) &
        $((char) 0) &
        $((char) 0) &
        $((char) 0) &
        $((char) 0)
    serialized = $((char) 0) & send.serialize() & "\r\n"
elif answer.toLower() == "receive":
    echo "Who would you like to receive from to?"
    address = stdin.readLine()
    echo "What nonce is the send block on their account?"
    inputNonce = newBN(stdin.readLine())
    echo "How much would you like to receive?"
    amount = newBN(stdin.readLine())
    echo "What nonce is this on your account?"
    nonce = newBN(stdin.readLine())

    recv = newReceive(
        address,
        inputNonce,
        amount,
        nonce
    )
    echo "Signing the Receive retuned... " & $wallet.sign(recv)

    header =
        $((char) 0) &
        $((char) 0) &
        $((char) 0) &
        $((char) 1) &
        $((char) 0)
    serialized = header & recv.serialize() & "\r\n"
else:
    echo "I don't recognize that option."
    quit(-1)

client.connect("127.0.0.1", Port(5132))
client.send(serialized)
sleep(100)
