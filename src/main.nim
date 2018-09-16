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

#SetOnce lib.
import SetOnce

#Async standard lib.
import asyncdispatch

#---------- Lattice ----------

var
    minter: Wallet = newWallet()     #Wallet.
    lattice: Lattice = newLattice()  #Lattice.
    mintIndex: Index = lattice.mint( #Mint transaction.
        minter.address,
        newBN("1000000")
    )
    mintRecv: Receive = newReceive(  #Mint Receive.
        mintIndex,
        newBN()
    )
#Sign and add the Mint Receive.
minter.sign(mintRecv)
discard lattice.add(mintRecv)

#Print the Private Key and address of the address holding the coins.
echo minter.address &
    " was minted, and has received, one million coins. Its Private Key is " &
    $minter.privateKey.toValue() & "."

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
        echo "From:   " & send.sender
        echo "To:     " & send.output
        echo "Amount: " & $send.amount.toValue()
        echo "\r\n"

        #Print before-balance, if the Lattice accepts it, and the new balance.
        echo "Balance of " & send.sender & ":     " & $lattice.getBalance(send.sender)
        echo "Adding: " &
            $lattice.add(
                send
            )
        echo "New balance of " & send.sender & ": " & $lattice.getBalance(send.sender)
)

#Handle Receives.
events.on(
    "recv",
    proc (recv: Receive) =
        #Print the message info.
        echo "Adding a new Receive."
        echo "From:   " & recv.inputAddress
        echo "To:     " & recv.sender
        echo "\r\n"

        #Print before-balance, if the Lattice accepts it, and the new balance.
        echo "Balance of " & recv.sender & ":     " & $lattice.getBalance(recv.sender)
        echo "Adding: " &
            $lattice.add(
                recv
            )
        echo "New balance of " & recv.sender & ": " & $lattice.getBalance(recv.sender) & "\r\n"
)

#Start listening.
network.start()

runForever()
