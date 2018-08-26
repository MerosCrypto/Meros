#Numerical libs.
import lib/BN
import lib/Base

#Wallet lib.
import Wallet/Wallet

#Lattice lib.
import Database/Lattice/Lattice

var
    sender: Wallet = newWallet()     #Sender Wallet.
    receiver: Wallet = newWallet()   #Receiver Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint(
        sender.getAddress(),
        newBN("10000000000")
    )                                #Index of the Mint TX.
    mintRecv: Receive = newReceive(  #Mint Receive.
        mintIndex.getAddress(),
        mintIndex.getNonce(),
        newBN("10000000000"),
        newBN()
    )
    send: Send = newSend(            #Send.
        receiver.getAddress(),
        newBN("10000000000"),
        newBN(1)
    )
    recv: Receive = newReceive(      #Receive.
        sender.getAddress(),
        newBN(1),
        newBN("10000000000"),
        newBN()
    )

echo "The coins were minted."
echo "\r\n"

#Sign and add the Mint Receive so the network has funds.
echo "Signing the Mint Receive returned: " & $sender.sign(mintRecv)
echo "Adding the Mint Receive returned:  " & $lattice.add(mintRecv)
echo "\r\n"

#Print the balances.
echo "The sender has:   " & $lattice.getBalance(sender.getAddress())
echo "The receiver has: " & $lattice.getBalance(receiver.getAddress())
echo "\r\n"

#Mine, sign, and add the Send.
send.mine(lattice.getTransactionDifficulty())
echo "Signing the Send returned: " & $sender.sign(send)
echo "Adding the Send returned:  " & $lattice.add(send)
echo "\r\n"

#Sign and add the Receive.
echo "Signing the Receive returned: " & $receiver.sign(recv)
echo "Adding the Receive returned:  " & $lattice.add(recv)
echo "\r\n"

#Print the final balances.
echo "The sender has:   " & $lattice.getBalance(sender.getAddress())
echo "The receiver has: " & $lattice.getBalance(receiver.getAddress())
