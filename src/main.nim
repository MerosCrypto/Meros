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

#String utils standard lib.
import strutils

#---------- Lattice ----------

var
    minter: Wallet = newWallet(
        "5893C9C209BE90DB9B72DA1F33FAA188CAD131280865B4814131C958F3732B12"
    )                                #Wallet.
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
    $minter.privateKey.toValue() & ".\r\n"

#---------- Network ----------
var
    events: EventEmitter = newEventEmitter() #EventEmitter for the Network.
    network: Network = newNetwork(0, events) #Network object.

#Handle Sends.
events.on(
    "send",
    proc (msg: Message, send: Send) =
        #Print the message info.
        echo "Adding a new Send."
        echo "From:   " & send.sender
        echo "To:     " & send.output
        echo "Amount: " & $send.amount.toValue()
        echo "\r\n"

        #Print before-balance, if the Lattice accepts it, and the new balance.
        echo "Balance of " & send.sender & ":     " & $lattice.getBalance(send.sender)
        var addResult: bool = lattice.add(
            send
        )
        if addResult:
            echo "Successfully added the Send."
            echo "New balance of " & send.sender & ": " & $lattice.getBalance(send.sender)
            network.broadcast(msg)
        else:
            echo "Failed to add the Send."
        echo ""
)

#Handle Receives.
events.on(
    "recv",
    proc (msg: Message, recv: Receive) =
        #Print the message info.
        echo "Adding a new Receive."
        echo "From:   " & recv.inputAddress
        echo "To:     " & recv.sender
        echo "\r\n"

        #Print before-balance, if the Lattice accepts it, and the new balance.
        echo "Balance of " & recv.sender & ":     " & $lattice.getBalance(recv.sender)
        var addResult: bool = lattice.add(
            recv
        )
        if addResult:
            echo "Successfully added the Receive."
            echo "New balance of " & recv.sender & ": " & $lattice.getBalance(recv.sender)
            network.broadcast(msg)
        else:
            echo "Failed to add the Receive."
        echo ""
)

#Define a var for input.
var input: string
#Read the port to listen on.
echo "Please enter the port to listen on."
input = stdin.readLine()
echo ""
#Start listening.
network.start(parseInt(input))

#Read in a port to connct to.
echo "Please enter a port to connect to."
input = stdin.readLine()
echo ""
if input != "":
    #Connect to that port.
    asyncCheck network.connect("127.0.0.1", parseInt(input))

#Run forever.
runForever()
