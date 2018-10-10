#Util lib.
import ../src/lib/Util

#Numerical libs.
import BN
import ../src/lib/Base

#Hash lib.
import ../src/lib/Hash

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Merit/Verifications

#Serialization libs.
import ../src/Network/Serialize/SerializeVerification

#Networking/OS standard libs.
import asyncnet, asyncdispatch

#String utils standard lib.
import strutils

var
    answer: string                         #Answer to questions.

    wallet: Wallet                         #Wallet.

    verif: MemoryVerification              #Verification.

    header: string =                       #Verification header.
        char(0) &
        char(0) &
        char(0)
    serialized: string                     #Serialized string.

    client: AsyncSocket = newAsyncSocket() #Socket.

#Get the Private Key.
echo "What's the Wallet's Private Key?"
answer = stdin.readLine()

#Create a Wallet from their Private Key.
wallet = newWallet(newPrivateKey(answer))

#Get the Node's hash.
echo "What Node do you want to verify?"
answer = stdin.readLine()

#Create the Verification object.
verif = newMemoryVerificationObj(answer.toHash(512))

#Sign the Verification.
wallet.sign(verif)

#Serialize the Verification.
serialized = verif.serialize()

#Connect to the server.
echo "Connecting..."
waitFor client.connect("127.0.0.1", Port(5132))
echo "Connected."
#Send the serialized node.
echo serialized.len
waitFor client.send(header & char(serialized.len) & serialized)
echo "Sent."
