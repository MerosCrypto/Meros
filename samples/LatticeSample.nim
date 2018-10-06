#Numerical libs.
import BN
import ../src/lib/Base

#Wallet lib.
import ../src/Wallet/Wallet

#Lattice lib.
import ../src/Database/Lattice/Lattice

#String utils standard lib.
import strutils

var
    sender: Wallet = newWallet()                        #Sender Wallet.
    receiver: Wallet = newWallet()                      #Receiver Wallet.
    lattice: Lattice = newLattice("bb".repeat(64), "")  #Lattice.
    mintIndex: Index = lattice.mint(
        sender.address,
        newBN(1000000)
    )                                                   #Index of the Mint TX.
    mintRecv: Receive = newReceive(                     #Mint Receive.
        mintIndex,
        newBN()
    )
    send: Send = newSend(                               #Send.
        receiver.address,
        newBN(1000000),
        newBN(1)
    )
    recv: Receive = newReceive(                         #Receive.
        sender.address,
        newBN(1),
        newBN()
    )

echo "The coins were minted."
echo ""

#Sign and add the Mint Receive so the network has funds.
sender.sign(mintRecv)
echo "Adding the Mint Receive returned: " & $lattice.add(nil, mintRecv)
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
