#BN lib.
import BN

#BLS and Miner Wallet libs.
import ../src/lib/BLS
import ../src/Database/Merit/MinerWallet

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#String utils standard lib.
import strutils

var
    miner: MinerWallet = newMinerWallet()               #Miner Wallet.
    sender: Wallet = newWallet()                        #Sender Wallet.
    receiver: Wallet = newWallet()                      #Receiver Wallet.
    lattice: Lattice = newLattice("bb".repeat(64), "")  #Lattice.
    mintNonce: uint = lattice.mint(                     #Nonce of the Mint.
        miner.publicKey.toString(),
        newBN(1000000)
    )
    mintClaim: Claim = newClaim(                        #Mint Claim.
        mintNonce,
        0
    )
    send: Send = newSend(                               #Send.
        receiver.address,
        newBN(1000000),
        1
    )
    recv: Receive = newReceive(                         #Receive.
        newIndex(
            sender.address,
            1
        ),
        0
    )

echo "The coins were minted."
echo ""

#Sign and add the Mint Claim so the network has funds.
mintClaim.sign(miner, sender)
echo "Adding the Mint Claim returned: " & $lattice.add(nil, mintClaim)
echo ""

#Print the balances.
echo "The sender has:   " & $lattice.getAccount(sender.address).balance
echo "The receiver has: " & $lattice.getAccount(receiver.address).balance
echo ""

#Mine, sign, and add the Send.
send.mine(lattice.difficulties.transaction)
echo "Signing the Send returned: " & $sender.sign(send)
echo "Adding the Send returned:  " & $lattice.add(nil, send)
echo ""

#Sign and add the Receive.
receiver.sign(recv)
echo "Adding the Receive returned: " & $lattice.add(nil, recv)
echo ""

#Print the final balances.
echo "The sender has:   " & $lattice.getAccount(sender.address).balance
echo "The receiver has: " & $lattice.getAccount(receiver.address).balance
