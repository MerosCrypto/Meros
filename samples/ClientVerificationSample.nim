#Hash lib.
import ../src/lib/Hash

#BLS lib.
import ../src/lib/BLS

#Merit lib.
import ../src/Database/Merit/Merit

#Serialization libs.
import ../src/Network/Serialize/Merit/SerializeVerifications

#Networking/OS standard libs.
import asyncnet, asyncdispatch

var
    answer: string                         #Answer to questions.

    wallet: MinerWallet                    #Wallet.

    verif: MemoryVerification              #Verification.

    handshake: string =                    #Handshake that says we're at Block 0.
        char(0) &
        char(0) &
        char(0) &
        char(1) & char(0)

    header: string =                       #Verification header.
        char(0) &
        char(0) &
        char(1)
    serialized: string                     #Serialized string.

    client: AsyncSocket = newAsyncSocket() #Socket.

#Get the Private Key.
echo "What's the Miner Wallet's Private Key?"
answer = stdin.readLine()

#Create a Wallet from their Private Key.
wallet = newMinerWallet(newBLSPrivateKeyFromBytes(answer))

#Get the Entry's hash.
echo "What Entry do you want to verify?"
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

#Send the Handshake.
waitFor client.send(handshake)
echo "Handshaked."

#Send the serialized Entry.
echo serialized.len
waitFor client.send(header & char(serialized.len) & serialized)
echo "Sent."
