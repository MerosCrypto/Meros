#Util lib.
import ../src/lib/Util

#Wallet libs.
import ../src/Wallet/Wallet
import ../src/Wallet/MinerWallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#Serialization libs.
import ../src/Network/Serialize/SerializeCommon
import ../src/Network/Serialize/Lattice/SerializeClaim

#Message object.
import ../src/Network/objects/MessageObj

#String utils standard lib.
import strutils

#Networking standard libs.
import asyncnet, asyncdispatch

var
    inputNonce: uint                          #Nonce of the Mint to Claim from.
    nonce: uint                               #Nonce of the Entry.

    miner: MinerWallet
    wallet: Wallet                            #Wallet.

    claim: Claim                              #Claim object.

    handshake: string =                       #Handshake that says we're at Block 0.
        char(MessageType.Handshake) &
        char(0) &
        char(0) &
        0.toBinary().pad(INT_LEN)

    claimType: char = char(MessageType.Claim) #Claim Message Type.

    socket: AsyncSocket = newAsyncSocket()    #Socket.

#Create the Miner Wallet.
echo "What's the BLS Private Key? "
miner = newMinerWallet(newBLSPrivateKeyFromBytes(stdin.readLine()))

#Create the Wallet.
echo "What's the Wallet's Seed? "
wallet = newWallet(newEdSeed(stdin.readLine()))

#Get the input nonce and the nonce.
echo "What nonce is the Mint Entry? "
inputNonce = parseUInt(stdin.readLine())
echo "What nonce is this on your account? "
nonce = parseUInt(stdin.readLine())

#Create the Claim.
claim = newClaim(
    inputNonce,
    nonce
)
#Sign the Claim.
claim.sign(miner, wallet)
echo "Signed the Claim."

#Connect to the server.
echo "Connecting..."
waitFor socket.connect("127.0.0.1", Port(5132))
echo "Connected."

#Send the Handshake.
waitFor socket.send(handshake)
echo "Handshaked."

#Send the Claim.
waitFor socket.send(claimType & claim.serialize())
echo "Sent."
