#BN lib.
import BN

#Wallet lib.
import Wallet/Wallet

#Lattice lib.
import Database/Lattice/Lattice

#Network lib.
import Network/Network

#Event lib.
import ec_events

#Async standard lib.
import asyncdispatch

#---------- Lattice ----------

var
    minter: Wallet = newWallet()     #Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint( #Mint transaction.
        minter.getAddress(),
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(  #Mint Receive.
        mintIndex,
        newBN()
    )
#Sign and add the Mint Receive.
discard minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Print the Private Key and address of the address holding the coins.
echo minter.getAddress() &
    " was minted, and has received, one million coins. Its Private Key is " &
    $minter.getPrivateKey() & "."

#---------- Network ----------
var
    events: EventEmitter = newEventEmitter() #EventEmitter for the Network.
    network: Network = newNetwork(0, events) #Network object.

#Handle Sends.
events.on(
    "send",
    proc (send: Send) =
        #Print the message info.
        echo "Adding a new Send."
        echo "From:   " & send.getSender()
        echo "To:     " & send.getOutput()
        echo "Amount: " & $send.getAmount()
        echo "\r\n"

        #Print before-balance, if the Lattice accepts it, and the new balance.
        echo "Balance of " & send.getSender() & ":     " & $lattice.getBalance(send.getSender())
        echo "Adding: " &
            $lattice.add(
                send
            )
        echo "New balance of " & send.getSender() & ": " & $lattice.getBalance(send.getSender())
)

#Handle Receives.
events.on(
    "recv",
    proc (recv: Receive) =
        #Print the message info.
        echo "Adding a new Receive."
        echo "From:   " & recv.getInputAddress()
        echo "To:     " & recv.getSender()
        echo "\r\n"

        #Print before-balance, if the Lattice accepts it, and the new balance.
        echo "Balance of " & recv.getSender() & ":     " & $lattice.getBalance(recv.getSender())
        echo "Adding: " &
            $lattice.add(
                recv
            )
        echo "New balance of " & recv.getSender() & ": " & $lattice.getBalance(recv.getSender()) & "\r\n"
)

#Start listening.
network.listen()

runForever()
