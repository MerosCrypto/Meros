#Util lib.
import ../src/lib/Util

#Numerical libs.
import BN
import ../src/lib/Base

#BLS lib.
import ../src/lib/BLS

#Wallet libs.
import ../src/Wallet/Wallet
import ../src/Database/Merit/MinerWallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#Serialization lib.
import ../src/Network/Serialize/Lattice/SerializeClaim

#Networking/OS standard libs.
import asyncnet, asyncdispatch

#String utils standard lib.
import strutils

var
    inputNonce: uint                       #Nonce of the Mint to Claim from.
    nonce: uint                            #Nonce of the Entry.

    miner: MinerWallet
    wallet: Wallet                         #Wallet.

    claim: Claim                           #Claim object.

    handshake: string =                    #Handshake that says we're at Block 0.
        char(0) &
        char(0) &
        char(0) &
        char(1) & char(0)

    handshakeOver: string =                #Handshake over message.
        char(0) &
        char(0) &
        char(5) &
        char(0)

    claimHeader: string =                   #Claim header.
        char(0) &
        char(0) &
        char(3)
    serialized: string                     #Serialized string.

    socket: AsyncSocket = newAsyncSocket() #Socket.

#Create the Miner Wallet.
echo "What's the BLS Private Key? "
miner = newMinerWallet(newBLSPrivateKeyFromBytes(stdin.readLine()))

#Create the Wallet.
echo "What's the Wallet's Seed? "
wallet = newWallet(newEdSeed(stdin.readLine()))

#Get the input nonce and the nonce.
echo "What nonce is the Mint Entry?"
inputNonce = parseUInt(stdin.readLine())
echo "What nonce is this on your account?"
nonce = parseUInt(stdin.readLine())

#Create the Claim.
claim = newClaim(
    inputNonce,
    nonce
)
#Sign the Claim.
claim.sign(miner, wallet)
echo "Signed the Claim."

#Create the serialized string.
serialized = claim.serialize()
serialized = claimHeader & char(serialized.len) & serialized

#Connect to the server.
echo "Connecting..."
waitFor socket.connect("127.0.0.1", Port(5134))
echo "Connected."

#Send the Handshake.
waitFor socket.send(handshake)
waitFor socket.send(handshakeOver)
echo "Handshaked."

#Send the serialized Entry.
waitFor socket.send(serialized)
echo "Sent."
